# Stream Deck Companion (Mobile to PC)

Transforme seu celular Android em um painel customizável de atalhos e botões estilo **Stream Deck**, enviando comandos em tempo real para o computador. 

Os comandos são injetados em **nível de hardware (DirectInput / Win32 / Linux X11)**, sendo reconhecidos perfeitamente por jogos e simuladores que ignoram emulações convencionais de teclado (como *Minecraft*, *Euro Truck Simulator 2*, *Assetto Corsa*, *Flight Simulator*, *OBS Studio*, *Discord*, etc.).

---

## ⚡ Download Rápido dos Instaladores (Pasta `release/`)

Para testar ou instalar imediatamente sem precisar compilar o código-fonte, utilize os arquivos pré-compilados disponíveis na pasta [release/](release/):

| Plataforma | Arquivo para Instalação | Formato |
| :--- | :--- | :--- |
| 📱 **Android** | [release/StreamDeck.apk](release/android/StreamDeck.apk) | APK de release (~48.9 MB) |
| 🪟 **Windows (Instalador)** | [release/windows/StreamDeckServer-Setup.exe](release/windows/StreamDeckServer-Setup.exe) | Instalador profissional Inno Setup (~25.7 MB) - *Recomendado* |
| 🪟 **Windows (Portátil)** | [release/windows/StreamDeckServer.exe](release/windows/StreamDeckServer.exe) | Executável portátil standalone (~35.0 MB) |
| 🪟 **Windows (Zip)** | [release/windows/StreamDeckServer-Windows.zip](release/windows/StreamDeckServer-Windows.zip) | Arquivo zip compactado (~34.7 MB) |
| 🐧 **Linux Mint / Ubuntu** | [release/linux/streamdeck-server_1.0.0_all.deb](release/linux/streamdeck-server_1.0.0_all.deb) | Pacote nativo `.deb` com ícone no Menu Iniciar (~551 KB) |
| 🐧 **Linux Script** | [release/linux/install.sh](release/linux/install.sh) ou [release/install.sh](release/install.sh) | Script automatizado de instalação via terminal |

---

## 🚀 Como Instalar e Usar

### 1. No Celular Android (App Mobile)
1. Baixe ou transfira o arquivo [release/StreamDeck.apk](release/StreamDeck.apk) para o smartphone (via WhatsApp, Google Drive, cabo USB ou Telegram).
2. No celular, toque em `StreamDeck.apk` para instalar.
3. Se o Android exibir o aviso para *"Instalar apps desconhecidos"*, toque em **Configurações** e marque **Permitir desta fonte**.
4. Conclua a instalação e abra o aplicativo.

### 2. No Computador (Servidor Host)

#### No Windows:
* **Opção 1 (Instalador Oficial - Recomendado)**:
  1. Baixe o instalador [release/windows/StreamDeckServer-Setup.exe](release/windows/StreamDeckServer-Setup.exe).
  2. Execute o instalador assistido. Ele cria automaticamente os atalhos no Menu Iniciar e na Área de Trabalho com os ícones oficiais, configura desinstalação limpa no Painel de Controle e inicializa instantaneamente sem extração temporária.
  3. *(Recomendado para jogos com privilégios elevados)*: Ao executar o servidor para simuladores ou jogos executados como Administrador, marque a opção ou execute como Administrador para permissões irrestritas de `SendInput`.
* **Opção 2 (Executável Portátil Standalone)**:
  1. Baixe o executável [release/windows/StreamDeckServer.exe](release/windows/StreamDeckServer.exe).
  2. Dê um duplo clique para iniciar. O servidor abrirá com o ícone oficial na **Barra de Tarefas do Windows** e exibirá o IP local da máquina.
  3. O servidor pode ser minimizado para a **área de ícones ocultos (Bandeja / System Tray)** e possui opção de inicialização automática com o Windows.

#### No Linux Mint / Ubuntu:
* **Opção 1 (1 Clique via GDebi)**:
  1. Dê um duplo clique no arquivo [release/linux/streamdeck-server_1.0.0_all.deb](release/linux/streamdeck-server_1.0.0_all.deb).
  2. O instalador de pacotes do Mint abrirá. Clique em **"Instalar Pacote"**.
  3. O atalho aparecerá automaticamente no **Menu Iniciar** procurando por *"Stream Deck Host"*, com o ícone oficial registrado.
* **Opção 2 (Terminal com script automatizado)**:
  ```bash
  chmod +x release/install.sh
  sudo ./release/install.sh
  ```
* **Opção 3 (Terminal direto via apt)**:
  ```bash
  sudo apt install ./release/linux/streamdeck-server_1.0.0_all.deb
  ```

---

## 🔗 Conectando o Celular ao Computador

1. Inicie o servidor no computador (Windows ou Linux).
2. Abra o aplicativo no celular.
3. **Conexão Automática (Wi-Fi)**: Desde que o celular e o PC estejam na mesma rede Wi-Fi, o aplicativo localizará o servidor automaticamente em menos de 2 segundos via **UDP Broadcast Auto-Discovery**, exibindo:
   `Host: <Nome-do-PC> (<IP>:8080)` com a bolinha verde de confirmação!
4. **Conexão via Cabo USB (Latência Zero / Sem Wi-Fi)**:
   * Conecte o celular ao PC via cabo USB (com depuração USB ativada).
   * No PC, execute:
     ```bash
     adb reverse tcp:8080 tcp:8080
     ```
   * No app, toque na barra de Host e insira o IP `127.0.0.1`.

---

## 🎮 Modos e Recursos do Aplicativo

* **Modo Generic (F13 a F24)**: Teclas de função estendidas que não conflitam com o teclado físico, perfeitas para mapear atalhos no OBS Studio, Discord, Streamlabs ou simuladores.
* **Modo Numpad Completo (Sub-label Dinâmica)**: Teclado numérico de 16 teclas (0 a 9, operadores matemáticos, ponto decimal e enter). Ao renomear uma tecla, a pílula inferior exibe automaticamente a tecla física mapeada no computador.
* **Modo Six Pack & Multimídia**: Teclas de navegação (Insert, Delete, Home, End, PageUp, PageDown) combinadas com controles de mídia do sistema operacional (Play/Pause, Faixa Anterior/Próxima, Volume +, Volume - e Mute).
* **Navegação por Swipe (Deslizar)**: Alterne instantaneamente entre as abas Generic, Numpad e Six Pack na Tela Principal apenas deslizando o dedo horizontalmente na tela.
* **Views Personalizadas (Custom Profiles)**: Crie abas com combinações livres de teclas selecionadas do catálogo e defina rótulos e aliases próprios para cada jogo ou perfil de trabalho.
* **Feedback Háptico**: Vibração tátil sutil ao acionar cada botão na tela.
* **Ações de Interruptor e Painel**: Toque rápido para acionar o comando no computador e liberar imediatamente (perfeito para painéis de carros, simuladores de voo e streaming); toque longo para personalizar o rótulo da tecla.

---

## 🛠️ Compilando a partir do Código-Fonte

Caso deseje desenvolver ou customizar o código:

### Servidor Python (`server/`):
```bash
# Dependências do sistema (no Linux Mint/Ubuntu):
sudo apt install -y python3-tk python3-pil libxtst6 x11-xserver-utils xmodmap

# Dependências Python:
cd server
pip install -r requirements.txt

# Executar o servidor:
python main.py        # Modo gráfico
python main.py --cli  # Modo terminal puro
```

### Aplicativo Flutter (`app/`):
```bash
cd app
flutter pub get
flutter test
flutter build apk --release
```

---

## 📚 Documentação Técnica e Guias para Agentes de IA

* [AGENT.md](AGENT.md): Guia operacional definitivo e especificações técnicas para desenvolvedores e agentes de IA (Antigravity, Claude Code, Cursor, Copilot).
* [WALKTHROUGH.md](WALKTHROUGH.md): Histórico arquitetural detalhado de todas as alterações e evoluções do projeto.

---

## 🔒 Segurança de Rede

O servidor utiliza comunicação por UDP na rede local sem requisição de senha para garantir mínima latência em jogos. **Recomenda-se utilizar o sistema exclusivamente em redes privadas e confiáveis** (como a rede Wi-Fi da sua residência) ou via cabo USB (`adb reverse`). Evite executá-lo em redes Wi-Fi públicas compartilhadas.

---

## 📄 License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). Free for personal, research, and noncommercial use.
