# O prompt

*[Read in English](PROMPT.md)*

Cole isso no Claude Code, Codex, Gemini CLI, Cursor, ou qualquer agente de IA com acesso a
terminal num computador na mesma rede que a Fire TV. Escrito para funcionar em **qualquer**
modelo/versão de Fire TV — começa fazendo o agente descobrir se (e como) o seu aparelho
específico pode realmente ser rooteado, em vez de assumir que é o mesmo `sheldon` /
`PS7717.5741N` em que o relato deste repositório ([README.pt-BR.md](README.pt-BR.md)) foi feito.

Repositório: `https://github.com/deniscouto/firetv-sheldon-root-debloat`

---

## Antes de começar: conseguindo acesso via ADB

Essa parte precisa ser feita na mão, com o controle remoto e olhando a tela da TV — um agente de
IA não tem como apertar botões na sua Fire TV nem ler a tela dela.

### 1. Descobrir o IP da Fire TV

Na Fire TV: **Configurações → Minha Fire TV → Sobre → Rede** (em algumas versões de Fire OS é
**Configurações → Rede**) mostra a rede Wi-Fi atual e o endereço IP diretamente.

### 2. Ativar as Opções do desenvolvedor

**Configurações → Minha Fire TV → Sobre**, selecione a linha com o nome/build do aparelho (varia
por versão de Fire OS — é a linha que fica embaixo, mostrando o nome do aparelho ou número de
série), e clique no botão de selecionar do controle **7 vezes rápido**. Uma mensagem "Agora você
é um desenvolvedor" confirma; uma nova opção **Opções do desenvolvedor** aparece uma tela atrás,
dentro de **Minha Fire TV**.

### 3. Ativar a depuração ADB

**Configurações → Minha Fire TV → Opções do desenvolvedor → Depuração ADB**, ative. Os sticks de
Fire TV não têm porta USB host, então isso é sempre depuração via rede (Wi-Fi), não USB.

### 4. Instalar o `adb` no seu computador

Ele vem junto com o `platform-tools` do Android.

**Windows:**
```powershell
winget install --id Google.PlatformTools -e
```
(ou baixe o `platform-tools` manualmente em
[developer.android.com/tools/releases/platform-tools](https://developer.android.com/tools/releases/platform-tools),
descompacte, e adicione a pasta ao `PATH`)

**Linux:**
```sh
# Debian/Ubuntu
sudo apt install android-sdk-platform-tools-common adb
# Fedora
sudo dnf install android-tools
# Arch
sudo pacman -S android-tools
```
(ou o mesmo zip manual do `platform-tools` da Google, se o pacote da sua distro estiver muito
desatualizado)

**macOS:**
```sh
brew install android-platform-tools
```

### 5. Conectar e parear

```sh
adb connect <IP>:5555
adb devices
```

Na **primeira** vez, aparece um aviso **na própria TV** — "Permitir depuração USB?" com a
impressão digital da chave RSA do seu computador. Aceite com o controle; marque "Sempre permitir
deste computador" pra não precisar repetir isso a cada reboot. Só quando `adb devices` mostrar o
aparelho como `device` (não `unauthorized` nem `offline`) você está pronto para o prompt abaixo.

---

### Copie este prompt no seu assistente:

```markdown
Quero rootear minha Amazon Fire TV, remover o bloatware, e trocar o launcher original por um
limpo (CleanYourTV), do jeito documentado em
https://github.com/deniscouto/firetv-sheldon-root-debloat. O IP da minha Fire TV é:
<IP AQUI>. Trabalhe no aparelho real, passo a passo, via ADB. Não chute compatibilidade —
verifique cada afirmação contra o aparelho de verdade e os repositórios originais antes de agir
em cima dela, e pare e me avise claramente se algo não se aplicar ao meu aparelho exato, em vez
de forçar uma adaptação.

Passo 0 — Identificar o aparelho exatamente
- `adb connect <IP>:5555`, depois leia `ro.product.device`, `ro.product.model`,
  `ro.build.version.name`, `ro.build.fingerprint`, e `cat /proc/version` (kernel) via
  `adb shell getprop` / `adb shell cat`.
- Todo esse processo é extremamente específico por build. Não assuma que o README deste
  repositório se aplica a outro codinome, outra versão de Fire OS, ou até outra build da mesma
  versão de Fire OS, até checar.

Passo 1 — Checar se o root é sequer possível para esse aparelho exato (faça isso ANTES de
qualquer outra coisa)
- Clone https://github.com/R0rt1z2/GhostLock e olhe **todas** as branches (`git branch -a` depois
  de clonar, ou confira no GitHub) — cada branch visa um hardware/kernel específico e diferente,
  não é um exploit universal. No momento em que isso foi escrito: a branch `4.4` visa a família
  `sheldon`/`sheldonp` em Fire OS 7 (kernel 4.4.x); a branch `4.14` visa o Fire TV Stick 4K Max
  1ª Gen (`kara`, kernel 4.14); a branch `main`/`5.10` visa hardware mais novo em Fire OS 8
  (Fire Max 11 `sunstone`, Fire TV Stick 4K Max 2ª Gen `karat`). Essa lista muda com o tempo — vá
  ver as branches atuais de verdade, não confie cegamente neste parágrafo.
- Na branch cujo codinome bater com seu aparelho, abra `src/gl_profiles_embedded.h` (ou a tabela
  de aparelhos do README) e procure uma entrada cujo `match_product` inclua seu
  `ro.product.device` exato, e idealmente cujo hash de kernel embutido tenha sido testado contra
  sua build exata — não só "parecida". Uma nota `reference` dizendo que o kernel de uma build é
  "kernel-identical-to-<outra build>-hardware-verified" já basta, mesmo que sua string de build
  literal não esteja listada separadamente.
- **Se nenhuma branch/perfil bater com seu aparelho: pare aqui.** Me avise claramente que não
  existe root público conhecido para esse aparelho/build, e que nenhum dos passos dependentes de
  root abaixo (takeover completo do launcher, `pm uninstall`, desativar pacotes protegidos) pode
  ser feito com segurança. Ofereça a alternativa sem root:
  o próprio `PROMPT.md` do https://github.com/saisarathbb/firetv-clean-root remove bloatware e
  instala um launcher customizado usando só `pm disable-user`/sideload, sem exploit, sem root —
  seguro em qualquer Fire TV, mas não consegue substituir totalmente a Home original nem mexer em
  pacotes protegidos.

Passo 2 — Root (só se o passo 1 achou uma correspondência real)
- Siga a seção "1. Root (GhostLock)" do README deste repositório usando a branch/perfil exatos
  que você encontrou. Num host Windows, use o [`root/root_win.sh`](root/root_win.sh) deste
  repositório em vez do `root.sh` original — o Git Bash puro trava para sempre em
  `wait-for-device` para um aparelho conectado por Wi-Fi e bagunça caminhos remotos; o README
  explica exatamente por quê.
- Confirme o root com um `adb shell "su -c 'id'"` **novo** (um shell novo, não o que o próprio
  exploit abriu) antes de confiar nele: `uid=0(root)`.

Passo 3 — Debloat
- Confira se `debloat/` neste repositório, ou `examples/` em
  https://github.com/saisarathbb/firetv-clean-root (`profiles/`) ou
  https://github.com/Gathin23/cleanyourtv (`examples/`), já tem uma lista para seu codinome
  exato. Se não, monte uma de forma conservadora a partir de `pm list packages`, priorizando
  padrões conhecidos de nomes de pacote de telemetria/anúncios da Amazon
  (`com.amazon.*metrics*`, `*ads*`, `*minerva*`, etc.) e deixando ativado qualquer coisa que você
  não tenha certeza.
- Só `pm disable-user --user 0 <pkg>`. Nunca `pm uninstall` um pacote de `/system`, nunca mexa no
  Bluetooth, no teclado na tela, ou no próprio app de Configurações.

Passo 4 — Launcher
- Compile o `launcher/` do https://github.com/Gathin23/cleanyourtv a partir do código-fonte, em
  vez de usar qualquer APK pré-compilado que encontrar por aí — veja o README deste repositório
  para entender por quê (um APK pré-compilado pode ser anterior silenciosamente a recursos de
  configuração que você está contando usar; confira seu `classes.dex`/`resources.arsc` atrás das
  chaves de configuração que pretende usar antes de confiar nele).
- Os dois patches em [`launcher-patch/`](launcher-patch/) (ícones não-leanback com a arte real,
  um botão dedicado de Bluetooth/Controles na barra superior) se generalizam para a maioria das
  versões de Fire OS, mas os nomes exatos de pacote/activity/action que eles referenciam
  (`com.amazon.tv.settings.v2`, `android.settings.CONTROLLERS_SETTINGS`, a action
  `FEATURED_LAUNCH` da Appstore, o alvo de fallback `settings_fallback_components`) devem ser
  reverificados com `dumpsys package` no seu aparelho em vez de assumidos — eles já mudaram entre
  versões de Fire OS antes e podem mudar de novo.
- Assine com seu próprio keystore, instale, desative o launcher original, use
  `set-home-activity`. Confirme que a Home realmente resolve para o novo launcher
  (`cmd package resolve-activity ... CATEGORY_HOME`) antes de desativar qualquer coisa além disso
  — não deixe a TV num estado sem nenhuma Home funcionando.

Passo 5 — OTA
- Desative `com.amazon.device.software.ota`, `.override`, e
  `com.amazon.tv.forcedotaupdater.v2` para que nada disso seja revertido silenciosamente.

Durante todo o processo: confirme que cada passo destrutivo realmente funcionou (releia o estado
via ADB) antes de seguir para o próximo, e me avise claramente se algo não bater com o que este
repositório descreve para o aparelho dele, em vez de forçar a adaptação.
```
