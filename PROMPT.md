# The prompt

*[Leia em português](PROMPT.pt-BR.md)*

Paste this into Claude Code, Codex, Gemini CLI, Cursor, or any coding agent with shell access on a
computer on the same network as the Fire TV. Written to work on **any** Fire TV model/Fire OS
version — it starts by having the agent figure out whether (and how) your specific device can
actually be rooted at all, instead of assuming it's the same `sheldon` / `PS7717.5741N` this
repo's own write-up ([README.md](README.md)) was done on.

Repository: `https://github.com/deniscouto/firetv-sheldon-root-debloat`

---

## Before you start: getting ADB access

This part has to be done by hand, on the remote and the TV screen — an AI agent has no way to
press buttons on your Fire TV or read its screen.

### 1. Find the Fire TV's IP address

On the Fire TV: **Settings → My Fire TV → About → Network** (on some Fire OS versions it's
**Settings → Network**) shows the current Wi-Fi network and IP address directly.

### 2. Turn on Developer Options

**Settings → My Fire TV → About**, highlight the device's own name/build line (varies by Fire OS
version — it's whichever line sits at the bottom, showing the device name or serial), and click
the remote's select button **7 times quickly**. A "You are now a developer" toast confirms it; a
new **Developer Options** entry appears one screen back, under **My Fire TV**.

### 3. Turn on ADB debugging

**Settings → My Fire TV → Developer Options → ADB debugging**, turn it on. Fire TV sticks have no
USB host port, so this is always debugging over the network (Wi-Fi), not USB.

### 4. Install `adb` on your computer

It ships as part of Android's `platform-tools`.

**Windows:**
```powershell
winget install --id Google.PlatformTools -e
```
(or download `platform-tools` manually from
[developer.android.com/tools/releases/platform-tools](https://developer.android.com/tools/releases/platform-tools),
unzip it, and add the folder to your `PATH`)

**Linux:**
```sh
# Debian/Ubuntu
sudo apt install android-sdk-platform-tools-common adb
# Fedora
sudo dnf install android-tools
# Arch
sudo pacman -S android-tools
```
(or the same manual `platform-tools` zip from Google, if your distro's package is too old)

**macOS:**
```sh
brew install android-platform-tools
```

### 5. Connect and pair

```sh
adb connect <IP>:5555
adb devices
```

The **first** time, a prompt appears **on the TV itself** — "Allow USB debugging?" with your
computer's RSA key fingerprint. Accept it with the remote; tick "Always allow from this computer"
so you don't have to repeat this on every reboot. Only once `adb devices` shows the device as
`device` (not `unauthorized` or `offline`) are you ready for the prompt below.

---

### Copy this prompt into your assistant:

```markdown
I want to root my Amazon Fire TV, debloat it, and replace the stock launcher with a clean one
(CleanYourTV), the way it's documented at
https://github.com/deniscouto/firetv-sheldon-root-debloat. My Fire TV's IP is: <IP ADDRESS HERE>.
Work on the real device, step by step, over ADB. Do not guess compatibility — verify every claim
against the actual device and the actual upstream repos before acting on it, and stop and tell me
plainly if something doesn't apply to my exact device instead of improvising around it.

Step 0 — Identify the device exactly
- `adb connect <IP>:5555`, then read `ro.product.device`, `ro.product.model`,
  `ro.build.version.name`, `ro.build.fingerprint`, and `cat /proc/version` (kernel) over
  `adb shell getprop` / `adb shell cat`.
- This whole process is extremely build-specific. Don't assume anything from this repo's own
  README applies to a different codename, Fire OS version, or even a different build number of
  the same Fire OS version, until you've checked.

Step 1 — Check whether root is even possible for this exact device (do this BEFORE anything else)
- Clone https://github.com/R0rt1z2/GhostLock and look at **all** its branches
  (`git branch -a` after cloning, or check on GitHub) — each branch targets different, specific
  hardware/kernel combinations, not one universal exploit. As of this writing: branch `4.4`
  targets the `sheldon`/`sheldonp` family on Fire OS 7 (kernel 4.4.x); branch `4.14` targets the
  Fire TV Stick 4K Max 1st Gen (`kara`, kernel 4.14); the `main`/`5.10` branch targets newer
  Fire OS 8 hardware (Fire Max 11 `sunstone`, Fire TV Stick 4K Max 2nd Gen `karat`). This list
  changes over time — go look at the actual current branches, don't trust this paragraph blindly.
- On whichever branch's codename matches your device, open `src/gl_profiles_embedded.h` (or the
  README's device table) and look for an entry whose `match_product` includes your exact
  `ro.product.device`, and ideally whose embedded kernel hash was tested against your exact build
  number — not just "close". A `reference` note saying a build's kernel is
  "kernel-identical-to-<other build>-hardware-verified" is good enough even if your literal build
  string isn't separately listed.
- **If no branch/profile matches your device at all: stop here.** Tell me plainly that there's no
  known public root for this device/build, and that none of the root-dependent steps below
  (full launcher takeover, `pm uninstall`, disabling protected packages) can be done safely. Offer
  the no-root alternative instead: https://github.com/saisarathbb/firetv-clean-root's own
  `PROMPT.md` debloats + installs a custom launcher using only `pm disable-user`/sideloading, no
  exploit, no root — safe on any Fire TV, but can't fully replace the stock Home or touch
  protected packages.

Step 2 — Root (only if step 1 found a real match)
- Follow this repo's README section "1. Root (GhostLock)" using the exact branch/profile you
  matched. On a Windows host, use [`root/root_win.sh`](root/root_win.sh) from this repo instead of
  upstream's `root.sh` — plain Git Bash hangs forever on `wait-for-device` for a Wi-Fi-connected
  device and mangles remote paths; the README explains exactly why.
- Confirm root with a **fresh** `adb shell "su -c 'id'"` (a new shell, not the one the exploit
  itself opened) before trusting it: `uid=0(root)`.

Step 3 — Debloat
- Check if `debloat/` in this repo, or `examples/` in
  https://github.com/saisarathbb/firetv-clean-root (`profiles/`) or
  https://github.com/Gathin23/cleanyourtv (`examples/`), already has a list for your exact
  codename. If not, build one conservatively from `pm list packages`, favouring known Amazon
  telemetry/ads package-name patterns (`com.amazon.*metrics*`, `*ads*`, `*minerva*`, etc.) and
  leaving anything you're unsure about enabled.
- `pm disable-user --user 0 <pkg>` only. Never `pm uninstall` a `/system` package, never touch
  Bluetooth, the on-screen keyboard, or the Settings app itself.

Step 4 — Launcher
- Build https://github.com/Gathin23/cleanyourtv's `launcher/` from source rather than using any
  bundled prebuilt APK — see this repo's README for why (a prebuilt APK can silently predate
  config features you're relying on; check its `classes.dex`/`resources.arsc` for the config keys
  you plan to use before trusting it).
- The two patches in [`launcher-patch/`](launcher-patch/) (non-leanback tiles with real artwork,
  a dedicated Bluetooth/Controllers top-bar button) generalize to most Fire OS versions, but the
  exact package/activity/action names they reference (`com.amazon.tv.settings.v2`,
  `android.settings.CONTROLLERS_SETTINGS`, the Appstore's `FEATURED_LAUNCH` action, the
  `settings_fallback_components` fallback target) should be re-verified with `dumpsys package` on
  your device rather than assumed — they've moved between Fire OS versions before and may again.
- Sign with your own keystore, install, disable the stock launcher, `set-home-activity`. Verify
  Home actually resolves to the new launcher (`cmd package resolve-activity ... CATEGORY_HOME`)
  before disabling anything further — don't leave the TV in a state with no working Home.

Step 5 — OTA
- Disable `com.amazon.device.software.ota`, `.override`, and `com.amazon.tv.forcedotaupdater.v2`
  so none of this gets silently reverted.

Throughout: confirm each destructive step actually worked (re-read the state over ADB) before
moving to the next one, and tell me plainly if something doesn't match what this repo describes
for its own device instead of forcing it to fit.
```
