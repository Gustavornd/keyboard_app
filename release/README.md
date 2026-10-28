# Pacote de Produção - Stream Deck Companion

Este diretório contém a versão de produção completa do ecossistema **Stream Deck**, pronta para instalação e testes em dispositivos móveis e computadores.

---

## 📁 Estrutura dos Arquivos

```text
release/
├── README.md                            # Este guia de instalação
├── StreamDeck.apk                       # Aplicativo Android (acesso direto)
│
├── android/
│   └── StreamDeck.apk                   # Cópia para distribuição Android
│
├── windows/
│   ├── StreamDeckServer.exe             # Executável portátil para Windows (com ícone nativo)
│   └── StreamDeckServer-Windows.zip     # Arquivo compactado para compartilhamento
│
└── linux/
    ├── streamdeck-server_1.0.0_all.deb  # Instalador nativo para Linux Mint / Ubuntu
    └── install.sh                       # Script de instalação automatizada via terminal
```

---

## 📱 1. Aplicativo Mobile (Android 12+)

### Arquivo: `StreamDeck.apk` (ou `android/StreamDeck.apk`)
* **Tamanho**: ~48.9 MB
* **Recursos**:
  * Descoberta Automática de Host na rede local Wi-Fi.
  * Modos pré-configurados: **Generic (F13 a F24)**, **Numpad completo** e **Six Pack / Mídia**.
  * Views Customizadas (permite criar perfis personalizados e escolher teclas).
  * Feedback háptico ao tocar nas teclas.

### Como Instalar no Celular:
1. Transfira o arquivo `StreamDeck.apk` para o celular (via WhatsApp, Google Drive, cabo USB ou Telegram).
2. No celular, toque no arquivo `StreamDeck.apk` para instalar.
3. Se o Android solicitar permissão para *"Instalar apps desconhecidos"*, toque em **Configurações** e marque **Permitir desta fonte**.
4. Conclua a instalação e abra o aplicativo.

---

## 🪟 2. Servidor Host para Windows

### Arquivo: `windows/StreamDeckServer.exe`
* **Tipo**: Executável único autocontido (Standalone EXE).
* **Compatibilidade**: Windows 10 e Windows 11 (64-bit).
* **Recursos**:
  * **Ícone Oficial na Barra de Tarefas**: Registrado via `AppUserModelID` Win32 (sem o ícone padrão do Python).
  * **Injeção de Hardware DirectInput**: Suporte nativo para jogos como Minecraft, Euro Truck Simulator, OBS Studio, etc.
  * **Minimizar para a Bandeja**: Executa em segundo plano na área de ícones ocultos (`^`).
  * **Iniciar com o Windows**: Opção integrada via registro do Windows.
  * **Auto-Discovery**: Responde a buscas da rede local emitidas pelo app.

### Como Executar:
1. Basta dar um duplo clique em `StreamDeckServer.exe`.
2. Ao abrir, o servidor exibirá o seu IP local e já estará pronto para receber conexões.
3. *(Recomendado para jogos protegidos/elevados)*: Clique com o botão direito e escolha **"Executar como Administrador"** para garantir permissões de injeção `SendInput` em todos os jogos.

---

## 🐧 3. Servidor Host para Linux Mint / Ubuntu

### Arquivo: `linux/streamdeck-server_1.0.0_all.deb`
* **Compatibilidade**: Linux Mint (Cinnamon, MATE, Xfce) e Ubuntu LTS (20.04, 22.04, 24.04).
* **Recursos**:
  * Integração com o **Menu Iniciar do Linux Mint** com ícone oficial.
  * Comando global no terminal: `streamdeck-server`.
  * Injeção nativa de eventos de teclado via **X11 Xtst** e mapeamento automático de teclas F13-F24 via `xmodmap`.

### Como Instalar no Linux Mint:
* **Método 1 (Interface Gráfica - 1 Clique)**:
  1. Dê um duplo clique no arquivo `streamdeck-server_1.0.0_all.deb`.
  2. O Instalador de Pacotes do Linux Mint (**GDebi**) será aberto.
  3. Clique em **"Instalar Pacote"** e informe sua senha de administrador.
  4. Pronto! O servidor aparecerá no Menu Iniciar procurando por *"Stream Deck Host"*.

* **Método 2 (Terminal com script automatizado)**:
  Abra a pasta no terminal e execute:
  ```bash
  sudo ./install.sh
  ```

* **Método 3 (Terminal direto via apt)**:
  ```bash
  sudo apt install ./streamdeck-server_1.0.0_all.deb
  ```

---

## 🔗 Como Conectar App e Servidor

1. Abra o servidor no PC (Windows ou Linux).
2. Abra o app no celular (certifique-se de que celular e PC estejam no **mesmo Wi-Fi**).
3. O app detectará o computador automaticamente em menos de 2 segundos, exibindo `Host: <Nome-do-PC> (<IP>:8080)` com a bolinha verde de confirmação!
4. *(Opcional - Cabo USB)*: Caso queira jogar via cabo USB sem Wi-Fi, conecte o celular via USB, digite `127.0.0.1` no app e execute no PC:
   ```bash
   adb reverse tcp:8080 tcp:8080
   ```

