import socket
import json
import sys
import os
import subprocess
import time
import ctypes

# Configurações do servidor UDP
HOST = '0.0.0.0'
PORT = 8080

# Constantes da API Win32 SendInput
INPUT_MOUSE = 0
INPUT_KEYBOARD = 1
INPUT_HARDWARE = 2

KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004
KEYEVENTF_SCANCODE = 0x0008

# Estruturas Win32 para SendInput (compatíveis com 32 e 64 bits)
class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", ctypes.c_uint16),
        ("wScan", ctypes.c_uint16),
        ("dwFlags", ctypes.c_uint32),
        ("time", ctypes.c_uint32),
        ("dwExtraInfo", ctypes.c_size_t),
    ]

class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", ctypes.c_int32),
        ("dy", ctypes.c_int32),
        ("mouseData", ctypes.c_uint32),
        ("dwFlags", ctypes.c_uint32),
        ("time", ctypes.c_uint32),
        ("dwExtraInfo", ctypes.c_size_t),
    ]

class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", ctypes.c_uint32),
        ("wParamL", ctypes.c_uint16),
        ("wParamH", ctypes.c_uint16),
    ]

class _INPUT_UNION(ctypes.Union):
    _fields_ = [
        ("mi", MOUSEINPUT),
        ("ki", KEYBDINPUT),
        ("hi", HARDWAREINPUT),
    ]

class INPUT(ctypes.Structure):
    _anonymous_ = ("u",)
    _fields_ = [
        ("type", ctypes.c_uint32),
        ("u", _INPUT_UNION),
    ]

LPINPUT = ctypes.POINTER(INPUT)

# Tabela detalhada de teclas para Windows:
# Formato: key_name: (VirtualKey, HardwareScanCode, isExtended, useScanCodeFlag)
WIN_KEY_CONFIG = {
    # Teclas F13 a F24 (Streamlabs, OBS, DAW - sem conflito com Minecraft ou teclado físico)
    # Enviadas com wVk e wScan OEM válidos (sem KEYEVENTF_SCANCODE para que o layout do Windows mantenha o VK_F13..F24)
    'f13': (0x7C, 0x64, False, False),
    'f14': (0x7D, 0x65, False, False),
    'f15': (0x7E, 0x66, False, False),
    'f16': (0x7F, 0x67, False, False),
    'f17': (0x80, 0x68, False, False),
    'f18': (0x81, 0x69, False, False),
    'f19': (0x82, 0x6A, False, False),
    'f20': (0x83, 0x6B, False, False),
    'f21': (0x84, 0x6C, False, False),
    'f22': (0x85, 0x6D, False, False),
    'f23': (0x86, 0x6E, False, False),
    'f24': (0x87, 0x6F, False, False),

    # Teclado Numérico / Numpad (DirectInput Hardware Scancodes para Minecraft, ETS2, Flight Sim)
    # Enviadas com KEYEVENTF_SCANCODE para injeção direta no driver de hardware / DirectInput
    'numpad_0': (0x60, 0x52, False, True),
    'numpad_1': (0x61, 0x4F, False, True),
    'numpad_2': (0x62, 0x50, False, True),
    'numpad_3': (0x63, 0x51, False, True),
    'numpad_4': (0x64, 0x4B, False, True),
    'numpad_5': (0x65, 0x4C, False, True),
    'numpad_6': (0x66, 0x4D, False, True),
    'numpad_7': (0x67, 0x47, False, True),
    'numpad_8': (0x68, 0x48, False, True),
    'numpad_9': (0x69, 0x49, False, True),
    'numpad_add': (0x6B, 0x4E, False, True),
    'numpad_sub': (0x6D, 0x4A, False, True),
    'numpad_mul': (0x6A, 0x37, False, True),
    'numpad_div': (0x6F, 0x35, True, True),
    'numpad_enter': (0x0D, 0x1C, True, True),
    'numpad_dot': (0x6E, 0x53, False, True),
    'numpad_decimal': (0x6E, 0x53, False, True),

    # Aliases numpad
    'num_0': (0x60, 0x52, False, True),
    'num_1': (0x61, 0x4F, False, True),
    'num_2': (0x62, 0x50, False, True),
    'num_3': (0x63, 0x51, False, True),
    'num_4': (0x64, 0x4B, False, True),
    'num_5': (0x65, 0x4C, False, True),
    'num_6': (0x66, 0x4D, False, True),
    'num_7': (0x67, 0x47, False, True),
    'num_8': (0x68, 0x48, False, True),
    'num_9': (0x69, 0x49, False, True),

    # Teclas de navegação adicionais (usadas para atalhos em mods e jogos)
    'insert': (0x2D, 0x52, True, True),
    'delete': (0x2E, 0x53, True, True),
    'home': (0x24, 0x47, True, True),
    'end': (0x23, 0x4F, True, True),
    'pageup': (0x21, 0x49, True, True),
    'page_up': (0x21, 0x49, True, True),
    'pagedown': (0x22, 0x51, True, True),
    'page_down': (0x22, 0x51, True, True),
    'scroll_lock': (0x91, 0x46, False, True),
    'pause': (0x13, 0x45, True, True),

    # Teclas de Mídia Globais (Media Keys)
    # Enviadas com Virtual Key e flag KEYEVENTF_EXTENDEDKEY para controle em segundo plano
    'media_play_pause': (0xB3, 0x22, True, False),
    'play_pause': (0xB3, 0x22, True, False),
    'media_next': (0xB0, 0x19, True, False),
    'next_track': (0xB0, 0x19, True, False),
    'media_prev': (0xB1, 0x10, True, False),
    'prev_track': (0xB1, 0x10, True, False),
    'media_stop': (0xB2, 0x24, True, False),
    'volume_mute': (0xAD, 0x20, True, False),
    'volume_up': (0xAF, 0x30, True, False),
    'volume_down': (0xAE, 0x2E, True, False),
}

def build_win_input(vk: int, scan: int, is_extended: bool, is_up: bool, use_scancode: bool) -> INPUT:
    """Constrói a estrutura INPUT do Win32 para SendInput preenchendo tanto wVk quanto wScan."""
    flags = 0
    if is_extended:
        flags |= KEYEVENTF_EXTENDEDKEY
    if is_up:
        flags |= KEYEVENTF_KEYUP
    if use_scancode:
        flags |= KEYEVENTF_SCANCODE

    ki = KEYBDINPUT(
        wVk=vk,
        wScan=scan,
        dwFlags=flags,
        time=0,
        dwExtraInfo=0
    )
    return INPUT(type=INPUT_KEYBOARD, ki=ki)


class InputController:
    """
    Controlador universal de entrada de teclado:
    - No Windows: Injeção de hardware via Win32 SendInput (F13-F24, Numpad DirectInput, Navigation).
    - No Linux: Suporta teclas padrão, F13-F24 e Numpad via X11 / libXtst (XTestFakeKeyEvent).
    """
    def __init__(self):
        self.mode = "none"
        self._press_times = {}
        self._init_backend()

    def _init_backend(self):
        # 1. Configuração Windows
        if sys.platform.startswith('win'):
            self.mode = "windows"
            try:
                self.user32 = ctypes.windll.user32
                self.user32.SendInput.argtypes = [ctypes.c_uint, LPINPUT, ctypes.c_int]
                self.user32.SendInput.restype = ctypes.c_uint
            except Exception as e:
                self.user32 = None
                print(f"ERRO [Windows]: Falha ao carregar user32.dll: {e}")

            try:
                import pydirectinput
                pydirectinput.PAUSE = 0.0
                self.pydirectinput = pydirectinput
            except ImportError:
                self.pydirectinput = None

            return

        # 2. Configuração Linux (X11)
        if sys.platform.startswith('linux'):
            try:
                self.ctypes = ctypes
                self.x11 = ctypes.CDLL('libX11.so.6')
                self.xtst = ctypes.CDLL('libXtst.so.6')

                self.x11.XOpenDisplay.restype = ctypes.c_void_p
                self.x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
                self.x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
                self.x11.XStringToKeysym.restype = ctypes.c_ulong
                self.x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
                self.x11.XKeysymToKeycode.restype = ctypes.c_ubyte
                self.x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
                self.xtst.XTestFakeKeyEvent.restype = ctypes.c_int
                self.xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
                self.x11.XFlush.argtypes = [ctypes.c_void_p]

                # Garante que F13 a F24 estejam mapeados no X11
                self._ensure_linux_f_keys()

                display_env = os.environ.get('DISPLAY', ':0').encode('utf-8')
                self.display = self.x11.XOpenDisplay(display_env)
                if self.display:
                    self.mode = "linux_x11"
                    self._key_cache = {}
                    self._alias_map = {
                        'space': b'space',
                        'enter': b'Return',
                        'return': b'Return',
                        'esc': b'Escape',
                        'escape': b'Escape',
                        'backspace': b'BackSpace',
                        'tab': b'Tab',
                        'shift': b'Shift_L',
                        'ctrl': b'Control_L',
                        'alt': b'Alt_L',
                    }
                    # Mapeia F13 a F24
                    for i in range(13, 25):
                        self._alias_map[f'f{i}'] = f'F{i}'.encode('ascii')
                    # Mapeia Numpad
                    for i in range(10):
                        self._alias_map[f'numpad_{i}'] = f'KP_{i}'.encode('ascii')
                        self._alias_map[f'num_{i}'] = f'KP_{i}'.encode('ascii')
                    self._alias_map['numpad_enter'] = b'KP_Enter'
                    self._alias_map['numpad_add'] = b'KP_Add'
                    self._alias_map['numpad_sub'] = b'KP_Subtract'
                    self._alias_map['numpad_mul'] = b'KP_Multiply'
                    self._alias_map['numpad_div'] = b'KP_Divide'
                    self._alias_map['numpad_dot'] = b'KP_Decimal'
                    self._alias_map['numpad_decimal'] = b'KP_Decimal'
                    self._alias_map['insert'] = b'Insert'
                    self._alias_map['delete'] = b'Delete'
                    self._alias_map['home'] = b'Home'
                    self._alias_map['end'] = b'End'
                    self._alias_map['pageup'] = b'Page_Up'
                    self._alias_map['page_up'] = b'Page_Up'
                    self._alias_map['pagedown'] = b'Page_Down'
                    self._alias_map['page_down'] = b'Page_Down'
                    self._alias_map['scroll_lock'] = b'Scroll_Lock'
                    self._alias_map['pause'] = b'Pause'
                    self._alias_map['media_play_pause'] = b'XF86AudioPlay'
                    self._alias_map['play_pause'] = b'XF86AudioPlay'
                    self._alias_map['media_next'] = b'XF86AudioNext'
                    self._alias_map['next_track'] = b'XF86AudioNext'
                    self._alias_map['media_prev'] = b'XF86AudioPrev'
                    self._alias_map['prev_track'] = b'XF86AudioPrev'
                    self._alias_map['media_stop'] = b'XF86AudioStop'
                    self._alias_map['volume_mute'] = b'XF86AudioMute'
                    self._alias_map['volume_up'] = b'XF86AudioRaiseVolume'
                    self._alias_map['volume_down'] = b'XF86AudioLowerVolume'
                    return
            except Exception as e:
                print(f"AVISO [Linux]: Não foi possível inicializar injeção X11: {e}")

        self.mode = "log_only"

    def _ensure_linux_f_keys(self):
        """Garante que o X11 tenha keycodes atribuídos para F13 a F24."""
        try:
            d = self.x11.XOpenDisplay(os.environ.get('DISPLAY', ':0').encode('utf-8'))
            if not d:
                return
            sym13 = self.x11.XStringToKeysym(b'F13')
            kc13 = self.x11.XKeysymToKeycode(d, sym13)
            self.x11.XCloseDisplay(d)

            # Se F13 ainda não tiver keycode no X11, aloca keycodes 183 a 194
            if kc13 == 0:
                cmd = []
                for i in range(13, 25):
                    kc = 183 + (i - 13)
                    cmd.extend(['-e', f'keycode {kc} = F{i} F{i} F{i} F{i}'])
                subprocess.run(['xmodmap'] + cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def _get_x11_keycode(self, key_str):
        if key_str in self._key_cache:
            return self._key_cache[key_str]

        lookup_name = self._alias_map.get(key_str, key_str.encode('ascii', errors='ignore'))
        keysym = self.x11.XStringToKeysym(lookup_name)
        if not keysym and len(key_str) == 1:
            keysym = ord(key_str)

        keycode = self.x11.XKeysymToKeycode(self.display, keysym)
        self._key_cache[key_str] = keycode
        return keycode

    def _get_last_error(self):
        """Retorna com segurança o código do último erro Win32."""
        if sys.platform.startswith('win'):
            try:
                return ctypes.windll.kernel32.GetLastError()
            except Exception:
                return 0
        return 0

    def _send_win_key(self, key_str, is_up):
        """Injeta a tecla no Windows usando SendInput nativo."""
        if not self.user32:
            return

        if key_str in WIN_KEY_CONFIG:
            vk, scan, is_extended, use_scancode = WIN_KEY_CONFIG[key_str]
            inp = build_win_input(vk, scan, is_extended, is_up, use_scancode)
            ret = self.user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))
            if ret != 1:
                err = self._get_last_error()
                if err == 5:  # ERROR_ACCESS_DENIED
                    print("ERRO [Windows]: SendInput bloqueado (UIPI). Execute o servidor como Administrador!")
                else:
                    print(f"AVISO [Windows]: SendInput retornou {ret} (código de erro: {err})")
        elif self.pydirectinput:
            try:
                if is_up:
                    self.pydirectinput.keyUp(key_str)
                else:
                    self.pydirectinput.keyDown(key_str)
            except Exception as e:
                print(f"AVISO [pydirectinput]: Falha ao injetar '{key_str}': {e}")
        else:
            # Fallback para teclas alfanuméricas avulsas
            try:
                vk = self.user32.VkKeyScanA(ord(key_str[0])) & 0xFF if len(key_str) == 1 else 0
                if vk:
                    scan = self.user32.MapVirtualKeyA(vk, 0)
                    inp = build_win_input(vk, scan, False, is_up, False)
                    self.user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))
            except Exception:
                pass

    def press(self, key_str):
        self._press_times[key_str] = time.time()
        # Windows
        if self.mode == "windows":
            self._send_win_key(key_str, is_up=False)
        # Linux
        elif self.mode == "linux_x11":
            code = self._get_x11_keycode(key_str)
            if code:
                self.xtst.XTestFakeKeyEvent(self.display, code, 1, 0)
                self.x11.XFlush(self.display)

    def release(self, key_str):
        # Garante retenção mínima de 50ms para taps ultra-rápidos de celulares,
        # assegurando que DirectInput (Minecraft) e Streamlabs capturem o evento
        press_time = self._press_times.pop(key_str, None)
        if press_time is not None:
            elapsed = time.time() - press_time
            if elapsed < 0.05:
                time.sleep(0.05 - elapsed)

        # Windows
        if self.mode == "windows":
            self._send_win_key(key_str, is_up=True)
        # Linux
        elif self.mode == "linux_x11":
            code = self._get_x11_keycode(key_str)
            if code:
                self.xtst.XTestFakeKeyEvent(self.display, code, 0, 0)
                self.x11.XFlush(self.display)

    def close(self):
        if self.mode == "linux_x11" and getattr(self, 'display', None):
            self.x11.XCloseDisplay(self.display)
            self.display = None


def check_windows_admin():
    """Verifica se o processo está em modo Administrador no Windows."""
    if sys.platform.startswith('win'):
        try:
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            return False
    return False


def start_server():
    input_ctrl = InputController()
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_socket.bind((HOST, PORT))

    print("=================================================")
    print(f" Servidor UDP iniciado na porta {PORT}")
    if input_ctrl.mode == "windows":
        is_admin = check_windows_admin()
        print(" [MODO WINDOWS]: Injeção nativa SendInput (F13-F24 e Numpad Scancodes) ATIVA")
        if is_admin:
            print(" [ADMIN]: Executando com privilégios de Administrador (UIPI bypassed).")
        else:
            print(" [AVISO]: Executando sem privilégios de Administrador.")
            print("          Se o jogo ou aplicativo de destino estiver rodando como Administrador,")
            print("          execute este terminal também como Administrador!")
    elif input_ctrl.mode == "linux_x11":
        print(" [MODO LINUX X11]: Injeção de Teclas Extras F13-F24 (Keycodes 183-194) ATIVA")
    else:
        print(" [MODO SOMENTE LOG]: Injeção no sistema desativada")
    print("=================================================")
    print("Aguardando comandos dos botões do Stream Deck...")
    print("DICA: Certifique-se de que o celular e o PC estão na mesma rede!")
    if sys.platform.startswith('win'):
        print("DICA WINDOWS: Permita o Python e a porta 8080 no Firewall do Windows.")
    print("Para sair, pressione CTRL+C.\n")

    try:
        while True:
            data, addr = server_socket.recvfrom(1024)
            try:
                message = json.loads(data.decode('utf-8'))
                key = message.get('key')
                action = message.get('action')

                if key and action:
                    key = str(key).lower()

                    if action == 'down':
                        input_ctrl.press(key)
                        print(f"[{addr[0]}] TECLA EXTRA PRESSIONADA (Down) : {key.upper()}")
                    elif action == 'up':
                        input_ctrl.release(key)
                        print(f"[{addr[0]}] TECLA EXTRA SOLTA (Up)       : {key.upper()}")
                    elif action == 'tap':
                        input_ctrl.press(key)
                        input_ctrl.release(key)
                        print(f"[{addr[0]}] TECLA EXTRA CLICADA (Tap)     : {key.upper()}")

            except json.JSONDecodeError:
                print(f"Mensagem inválida recebida de {addr}: {data}")
            except Exception as e:
                print(f"Erro ao processar comando para a tecla '{key}': {e}")

    except KeyboardInterrupt:
        print("\nEncerrando servidor...")
    finally:
        server_socket.close()
        input_ctrl.close()


if __name__ == "__main__":
    start_server()
