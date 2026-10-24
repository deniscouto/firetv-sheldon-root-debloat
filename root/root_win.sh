#!/bin/sh
# Windows/Git-Bash adapted driver for ghostlock_root (same protocol as root.sh,
# skipping the local -x check that NTFS/MSYS can't satisfy for the ARM ELF binary).
set +e
# Without this, MSYS rewrites /data/local/tmp/... remote paths into
# Windows paths before adb ever sees them (secure_mkdirs failed on device).
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

HERE=$(cd "$(dirname "$0")" && pwd -W)
ADB=adb
TARGET="${TV_HOST:-192.168.0.181}:5555"
REMOTE=/data/local/tmp/gl
LOG=$REMOTE/run.log
BIN="$HERE/build/ghostlock_root"

TRIES=${1:-15}
SETTLE=${SETTLE:-45}
POSTWAIT=${POSTWAIT:-30}

adb_state() { "$ADB" get-state 2>/dev/null | tr -d '\r'; }

reconnect() {
  "$ADB" disconnect "$TARGET" >/dev/null 2>&1 || true
  n=0
  while [ "$n" -lt 20 ]; do
    if "$ADB" connect "$TARGET" 2>&1 | grep -q "connected to"; then
      return 0
    fi
    n=$((n + 1))
    sleep 3
  done
  return 1
}

wait_boot() {
  # No blind wait-for-device: for a TCP/IP target it never re-arrives on its
  # own after a reboot, so poll with active `adb connect` instead.
  n=0
  while [ "$n" -lt 60 ]; do
    if "$ADB" connect "$TARGET" 2>&1 | grep -q "connected to"; then
      if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then
        break
      fi
    fi
    n=$((n + 1))
    sleep 3
  done
  sleep "$SETTLE"
  reconnect
}

stage() {
  if [ "$(adb_state)" != device ]; then echo "  [stage] device not online after reconnect"; return 1; fi
  if ! "$ADB" shell "rm -rf $REMOTE; mkdir -p $REMOTE"; then echo "  [stage] mkdir failed"; return 1; fi
  if ! "$ADB" push "$BIN" "$REMOTE/ghostlock_root"; then echo "  [stage] push binary failed"; return 1; fi
  if ! "$ADB" shell "chmod 755 $REMOTE/ghostlock_root"; then echo "  [stage] chmod failed"; return 1; fi
  return 0
}

for i in $(seq "$TRIES"); do
  echo "Attempt $i/$TRIES"
  if [ "$(adb_state)" = device ]; then
    "$ADB" reboot >/dev/null 2>&1 || true
  fi
  wait_boot
  stage || continue

  "$ADB" shell "cd $REMOTE && (nohup ./ghostlock_root >run.log 2>&1 &); sleep 1" >/dev/null 2>&1

  result=timeout
  rooted_seen=0
  postn=0
  downs=0
  n=0
  MAXN=120
  while [ "$n" -lt "$MAXN" ]; do
    n=$((n + 1))
    sleep 1
    if [ "$rooted_seen" = 0 ] && "$ADB" shell "grep -aq 'ROOT] uid=0 daemon' $LOG" 2>/dev/null; then
      rooted_seen=1
      result=rooted
      echo "  [poll] rooted signal seen at n=$n"
    fi
    if [ "$rooted_seen" = 1 ]; then
      postn=$((postn + 1))
      if [ "$postn" -ge "$POSTWAIT" ] || "$ADB" shell "grep -aq 'ota] done' $LOG" 2>/dev/null; then
        break
      fi
    fi
    if [ "$rooted_seen" = 0 ] && "$ADB" shell "grep -aqE 'preloaded read slot failed|holding reclaim' $LOG" 2>/dev/null; then
      result=failed
      echo "  [poll] failure signal seen at n=$n"
      break
    fi
    if [ "$(adb_state)" != device ]; then
      downs=$((downs + 1))
      [ "$downs" -ge 3 ] && { result=down; break; }
    else
      downs=0
    fi
  done

  echo "  [result] $result"
  if [ "$result" = rooted ]; then
    echo "ROOTED. Verifying with a fresh adb shell..."
    "$ADB" shell "/data/local/tmp/gl/ghostlock_root --su -c id" 2>&1
    "$ADB" shell "su -c id" 2>&1
    exit 0
  fi
done

echo "FAILED after $TRIES attempts."
exit 1
