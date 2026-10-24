# Fire TV Stick Lite (sheldon) — root + debloat + launcher limpo

*[Read in English](README.md)*

Um relato técnico completo de como rootear um Amazon Fire TV Stick Lite, remover bloatware, e
substituir o launcher original pelo [CleanYourTV](https://github.com/Gathin23/cleanyourtv),
incluindo dois pequenos patches no launcher: mostrar a Amazon Appstore (e outros pacotes que não
são "de TV") como um ícone com a arte real, e um botão dedicado de Bluetooth/Controles na barra
superior.

**Tem outro modelo de Fire TV ou outra versão de Fire OS?** O [`PROMPT.pt-BR.md`](PROMPT.pt-BR.md)
é feito para colar num agente de IA e fazê-lo checar a compatibilidade do seu aparelho específico
primeiro, em vez de assumir que é igual a este.

Tudo aqui foi feito contra o **modelo e build de firmware exatos abaixo** — se você tem o mesmo
aparelho (ou um build bem próximo), isso deve se aplicar diretamente. Se for outro modelo, ainda
pode ajudar, mas confira a compatibilidade primeiro (veja [Root](#1-root-ghostlock)).

## Aparelho exato testado

| | |
|---|---|
| **Modelo** | Amazon Fire TV Stick Lite (2020) |
| **Número do modelo (caixa/aparelho)** | AFTSS |
| **Codinome** | `sheldon` |
| **Fire OS** | 7.7.1.7 |
| **Build** | `PS7717.5741N` |
| **Incremental** | `0036408028416` |
| **Base Android** | 9 (Pie) |
| **Kernel** | `Linux 4.4.162+` |
| **SoC** | MediaTek MT8695D |

Se `adb shell getprop ro.build.fingerprint` no seu aparelho mostrar `sheldon` e `PS7717.5741N`
(ou um build próximo na lista do [README da branch `4.4` do GhostLock](https://github.com/R0rt1z2/GhostLock/tree/4.4)),
este guia se aplica diretamente a você.

## O que isso faz

1. Rooteia o aparelho (temporariamente, perdido no próximo reboot — isso é normal para esse exploit)
2. Remove ~50 pacotes de telemetria/anúncios/bloatware da Amazon (`pm disable-user`, nada é
   removido de `/system`)
3. Remove alguns apps extras que o dono não queria (Luna cloud gaming, o app de troubleshooting
   da Fire TV) e um launcher de terceiros que tinha ficado para trás
4. Substitui o launcher original da Amazon por um [CleanYourTV](https://github.com/Gathin23/cleanyourtv)
   compilado do zero, com patches para que:
   - A Amazon Appstore apareça como um ícone com a arte **real** (recortada diretamente da própria
     tela "Seus Aplicativos e Jogos" da Amazon, não um ícone genérico) e abra na página
     Destaques/principal, não na grade "Meus Apps"
   - **Bluetooth e Controles** ganhe seu próprio botão dedicado na barra superior, separado do
     botão geral de Configurações (que o fallback de configurações do próprio Fire OS, dependente
     do launcher original, quebraria assim que você desativa o launcher original — veja
     [correção do botão de Configurações](#correção-do-botão-de-configurações))
5. Bloqueia o atualizador OTA da Amazon para que nada disso seja revertido silenciosamente

## Capturas de tela

| Tela inicial | Bluetooth e Controles (via o novo botão) |
|---|---|
| ![home](screenshots/home_screen.png) | ![bluetooth](screenshots/bluetooth_settings.png) |

## 1. Root (GhostLock)

Isso usa o [R0rt1z2/GhostLock](https://github.com/R0rt1z2/GhostLock), **branch `4.4`** — não a
branch `main`/`5.10`, que hoje só visa hardware diferente e mais novo em Fire OS 8 (Fire Max 11,
Fire TV Stick 4K Max 2ª Gen). A branch `4.4` é um exploit separado, específico para
MediaTek-MT8695/8696 (adaptado da CVE-2026-43499 no CyberMeowfia), visando exatamente a família
`sheldon`/`sheldonp` em Fire OS 7, com um perfil testado em hardware para a build `PS7717.5741N`
(a nossa) já embutido em `src/gl_profiles_embedded.h`.

```sh
git clone https://github.com/R0rt1z2/GhostLock.git
cd GhostLock
git checkout 4.4
make NDK=/caminho/para/android-ndk-r27d   # toolchain ARM v7a, Android NDK r27d (ou defina CC=)
./root.sh                                  # Linux/macOS; reinicia o aparelho, tenta até 15x
```

### Windows / Git Bash

O `root.sh` assume um host POSIX (caminhos de `adb` estilo Linux/macOS) e trava para sempre em
`adb wait-for-device` após um reboot, para um aparelho conectado via **rede** (ADB por Wi-Fi), já
que esse comando nunca rearma sozinho um transporte TCP — é preciso chamar `adb connect` de novo
ativamente. O [`root/root_win.sh`](root/root_win.sh) deste repositório é uma reescrita do mesmo
protocolo, segura para Windows/Git Bash, que:

- Reconecta ativamente com `adb connect` depois de cada reboot, em vez de travar em
  `wait-for-device`
- Define `MSYS_NO_PATHCONV=1` / `MSYS2_ARG_CONV_EXCL="*"` para o Git Bash não reescrever o
  caminho **remoto** do Android `/data/local/tmp/gl/...` como um caminho falso do Windows
  (`secure_mkdirs failed`)
- Resolve o caminho do binário **local** com `pwd -W`, para continuar sendo um caminho real do
  Windows que o `adb.exe` (um binário Win32 nativo) consiga ler
- Pula a checagem `[ -x ...]` de bit de execução no binário ARM ELF compilado, que o NTFS/Git-Bash
  não consegue satisfazer mesmo depois de `chmod +x` (irrelevante de qualquer forma — o bit de
  execução real é setado no aparelho depois do push)

```sh
TRIES=15 sh root/root_win.sh
```

Uma vez rooteado, o `su` funciona em qualquer `adb shell` novo até o próximo reboot — não precisa
de daemon/wrapper.

## 2. Debloat

[`debloat/sheldon_lite_fireos7.txt`](debloat/sheldon_lite_fireos7.txt) é a lista de debloat do
Fire TV Stick Lite do [saisarathbb/firetv-clean-root](https://github.com/saisarathbb/firetv-clean-root)
(creditada lá ao banco de dados mais amplo de listas de debloat do
[Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv)). Aplicada com
`pm disable-user --user 0 <pkg>` simples, uma chamada por pacote, sobre um `adb shell` rooteado
novo — **desativar, nunca desinstalar**, para qualquer coisa dentro de `/system`.

```sh
while read -r pkg; do
  pkg="${pkg%%#*}"; [ -z "$pkg" ] && continue
  adb shell "su -c 'pm disable-user --user 0 $pkg'"
done < debloat/sheldon_lite_fireos7.txt
```

## 3. Launcher: compilação + patches

O toolkit em `firetv-clean-root` traz um APK **pré-compilado** do CleanYourTV que, descobrimos,
é anterior aos recursos de overlay de configuração `library_apps`/`launch_actions`/`app_banners`/
`dock_apps` por completo (nenhuma dessas strings aparece no seu `classes.dex`) — nenhum dos nossos
overrides via `config.json` em runtime teve qualquer efeito nele. Compilar o `launcher/` **atual**
do [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) a partir do código-fonte
(`./gradlew assembleRelease`, precisa de JDK 17 + Android SDK platform 34 + build-tools 34.0.0)
já trouxe esses recursos de imediato.

Dois pequenos patches em cima do `cleanyourtv` original (veja
[`launcher-patch/cleanyourtv.patch`](launcher-patch/cleanyourtv.patch) para o diff completo):

### Ícones para apps "não-leanback" com a arte real deles

Os próprios apps do Fire OS (a Appstore, Configurações) não declaram `CATEGORY_LEANBACK_LAUNCHER`
— foram construídos para o launcher original da Amazon, não para a convenção genérica de Android
TV que o CleanYourTV lê (por design). `dock_apps` / `library_apps` já permitem trazer um app com
`CATEGORY_LAUNCHER` que não é leanback, e `launch_actions` (`pkg=action`) já permite sobrescrever
o que o toque num ícone faz — por exemplo, a activity de lançamento simples da Appstore é
`.grid.AppsGridLauncherActivity` ("Seus Apps e Jogos"), não a home de destaques/vitrine;
`com.amazon.venezia.ade.FEATURED_LAUNCH` abre a de verdade.

O banner é [a arte real](launcher-patch/drawable/banner_venezia.png), recortada diretamente de um
`screencap` da própria tela "Seus Aplicativos e Jogos" da Amazon (não uma recriação), na mesma
proporção 16:9 que o próprio ícone do CleanYourTV (`180dp × 101dp`, veja `item_app.xml`) espera —
uma proporção quase certa, mas não exata, num `ImageView` com `centerCrop` é o que faz parecer
"não preencheu certinho o espaço".

### Botão dedicado de Bluetooth/Controles, e a correção do botão de Configurações

O app de Configurações (`com.amazon.tv.settings.v2`) **não tem nenhuma** activity com
`CATEGORY_LAUNCHER` — só telas específicas alcançáveis por action, então ele nunca consegue um
ícone pelo mecanismo acima, não importa a configuração (confirmado lendo `AppAdapter.reload()`:
um ícone só é criado a partir de um resultado de `queryIntentActivities(MAIN, LAUNCHER)`). O
`AppAdapter.java` foi corrigido para também sintetizar uma entrada de ícone (usando o próprio
ícone/rótulo do pacote via `PackageManager.getApplicationInfo`) para qualquer pacote em
`library_apps`/`dock_apps` que tenha um override em `launch_actions` mas nenhuma activity de
lançamento resolvível — `launch()` sempre monta o intent de `launch_actions` e o troca *antes* de
usar o componente sintético de verdade, então nada quebrado chega a ser realmente iniciado.

Esse caminho ainda só te dá um **ícone** na grade, porém — não uma pílula na barra superior como
Wi-Fi/Configurações. Um botão dedicado `btnBluetooth` (`activity_main.xml` + `MainActivity.java`)
foi adicionado em vez disso, estilizado de forma idêntica aos existentes, disparando
`android.settings.CONTROLLERS_SETTINGS` explicitamente ao clicar.

<a id="correção-do-botão-de-configurações"></a>**Por que o próprio botão de Configurações também
precisa de correção:** o `SystemSettings.intent()` do CleanYourTV já contorna o fato de o Fire OS
vincular `android.settings.SETTINGS` a um stub de conformidade CTS que não abre nada
(`CTSDummySettingsHandler`) — ele recorre ao primeiro componente instalado em
`settings_fallback_components`. A entrada padrão do Fire OS no `config.xml` original é
`com.amazon.tv.launcher/...MainSettingsActivity` — ou seja, **o próprio launcher original da
Amazon**, que todo este guia desativa no passo 4. Uma vez desativado, esse fallback resolve
silenciosamente para um componente morto e o botão de Configurações mostra "não disponível nesta
TV". Apontar essa mesma entrada para
`com.amazon.tv.settings.v2/com.amazon.tv.settings.v2.tv.device.DeviceActivity` em vez disso
restaura o funcionamento.

### Compilar e instalar

```sh
cd cleanyourtv/launcher
./gradlew assembleRelease
# assine com seu próprio keystore (qualquer chave; só precisa continuar a mesma nas suas próprias atualizações)
apksigner sign --ks sua.jks --out app-release-signed.apk app-release-aligned.apk
adb shell "su -c 'pm uninstall --user 0 com.gathin.tvhome'"   # só se uma chave diferente estava instalada antes
adb install -r app-release-signed.apk
adb shell "su -c 'pm disable-user --user 0 com.amazon.tv.launcher'"
adb shell "su -c 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity'"
```

## 4. Bloquear OTA

```sh
for pkg in com.amazon.device.software.ota com.amazon.device.software.ota.override com.amazon.tv.forcedotaupdater.v2; do
  adb shell "su -c 'pm disable-user --user 0 '$pkg"
done
```

## Revertendo

O root em si é perdido automaticamente no próximo reboot. Tudo o mais (debloat, launcher, apps
removidos, bloqueio de OTA) é estado persistente do gerenciador de pacotes do Android, não ligado
ao root — para reverter, use `pm enable`/reinstale os mesmos pacotes, o que precisa de root de
novo (as restrições de pacote protegido valem nos dois sentidos).

## Créditos

- [R0rt1z2/GhostLock](https://github.com/R0rt1z2/GhostLock) (branch `4.4`) — o exploit de root do
  kernel em si, com créditos adiante para o
  [CyberMeowfia](https://github.com/NebuSec/CyberMeowfia),
  [IonStackQuest3](https://github.com/F-19-F/IonStackQuest3) e
  [gitchw/ghostlock-cve-2026-43499](https://github.com/gitchw/ghostlock-cve-2026-43499)
- [saisarathbb/firetv-clean-root](https://github.com/saisarathbb/firetv-clean-root) — a lista de
  debloat e a ideia de combinar um exploit de root com o CleanYourTV no Fire OS
- [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) — o launcher em si

## Aviso

Rootear envolve um exploit de kernel e mudanças de baixo nível no gerenciador de pacotes. O
exploit em si é só em memória (não grava no bootloader/partições), e tudo aqui usa
`pm disable-user` em vez de mexer em `/system`, mas ainda é território "por sua conta e risco" —
veja os avisos nos repositórios creditados acima.
