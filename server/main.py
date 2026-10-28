import socket
import json
import sys
import os
import subprocess
import time
import ctypes
import threading
import argparse

# Módulos opcionais para Interface Gráfica e Bandeja do Sistema
try:
    import tkinter as tk
    from tkinter import messagebox
    TK_AVAILABLE = True
except ImportError:
    TK_AVAILABLE = False

try:
    import winreg
except ImportError:
    winreg = None

try:
    import pystray
    from PIL import Image, ImageDraw, ImageTk
    PIL_AVAILABLE = True
    PYSTRAY_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False
    PYSTRAY_AVAILABLE = False


# -------------------------------------------------------------
# AUTO-REDIRECIONAMENTO DE AMBIENTE PYTHON (WINDOWS)
# -------------------------------------------------------------
def ensure_correct_python_environment():
    """
    Garante que o script execute no interpretador Python do Windows com todas as dependências instaladas.
    Se iniciado pelo Python do MSYS2/MinGW onde pystray/Pillow podem não estar instalados,
    redireciona automaticamente para o 'py' ou o Python 3.11 do Windows.
    """
    if sys.platform != 'win32':
        return

    # Se já temos pystray e PIL disponíveis neste processo, o ambiente está perfeito!
    if PYSTRAY_AVAILABLE and PIL_AVAILABLE:
        return

    # Evita loops de redirecionamento caso uma tentativa anterior já tenha sido feita
    if os.environ.get("STREAM_DECK_ENV_CHECKED") == "1":
        return
    os.environ["STREAM_DECK_ENV_CHECKED"] = "1"

    candidates = [
        "py",
        r"C:\Program Files\Python311\python.exe",
        r"C:\Program Files\Python312\python.exe",
        r"C:\Program Files\Python310\python.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Python\Python311\python.exe"),
    ]

    for candidate in candidates:
        try:
            check_cmd = [candidate, "-c", "import pystray, PIL; print('READY')"]
            res = subprocess.run(check_cmd, capture_output=True, text=True, timeout=2)
            if "READY" in res.stdout:
                script_path = os.path.abspath(__file__)
                args = [candidate, script_path] + sys.argv[1:]
                subprocess.Popen(args)
                sys.exit(0)
        except Exception:
            continue


# Configurações padrão do servidor UDP
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
                    self._alias_map['pagedown'] = b'Page_Down'
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
                print(f"AVISO [Linux]: Não foi possível carregar X11/Xtst: {e}")

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


def check_windows_admin() -> bool:
    """Verifica se o processo está em modo Administrador no Windows."""
    if sys.platform.startswith('win'):
        try:
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            return False
    return False


# -------------------------------------------------------------
# DETECÇÃO DE IP LOCAL E UTILITÁRIOS DE REDE
# -------------------------------------------------------------
def get_local_ip() -> str:
    """Detecta o endereço IPv4 local da máquina na rede ativa."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return '127.0.0.1'


# -------------------------------------------------------------
# GERENCIAMENTO DE INICIALIZAÇÃO COM O WINDOWS (REGISTRY)
# -------------------------------------------------------------
REG_RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
REG_RUN_NAME = "StreamDeckServer"

def is_autostart_enabled() -> bool:
    """Verifica se o servidor está configurado para iniciar com o Windows."""
    if sys.platform != 'win32' or not winreg:
        return False
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_KEY, 0, winreg.KEY_READ) as key:
            val, _ = winreg.QueryValueEx(key, REG_RUN_NAME)
            return bool(val)
    except FileNotFoundError:
        return False
    except Exception:
        return False

def set_autostart(enable: bool) -> bool:
    """Habilita ou desabilita a inicialização automática com o Windows."""
    if sys.platform != 'win32' or not winreg:
        return False
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
            if enable:
                py_exe = sys.executable
                dir_name = os.path.dirname(py_exe)
                pyw_exe = os.path.join(dir_name, "pythonw.exe")
                exe = pyw_exe if os.path.isfile(pyw_exe) else py_exe
                script_path = os.path.abspath(__file__)
                cmd = f'"{exe}" "{script_path}" --minimized'
                winreg.SetValueEx(key, REG_RUN_NAME, 0, winreg.REG_SZ, cmd)
            else:
                try:
                    winreg.DeleteValue(key, REG_RUN_NAME)
                except FileNotFoundError:
                    pass
        return True
    except Exception as e:
        print(f"Erro ao configurar inicialização no Windows: {e}")
        return False


# -------------------------------------------------------------
# SERVIDOR UDP MULTI-THREADING (COM SUPORTE A START / STOP)
# -------------------------------------------------------------
class UDPServer:
    """Servidor UDP desacoplado que pode ser iniciado, pausado e encerrado dinamicamente."""
    def __init__(self, host=HOST, port=PORT, on_event=None):
        self.host = host
        self.port = port
        self.on_event = on_event  # callback(ip, key, action)
        self.input_ctrl = InputController()
        self.sock = None
        self.is_running = False
        self._thread = None
        self.commands_count = 0
        self.last_command = "Nenhum comando ainda"

    def start(self):
        if self.is_running:
            return
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            if hasattr(socket, 'SO_REUSEADDR'):
                self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.sock.bind((self.host, self.port))
            self.sock.settimeout(0.5)
            self.is_running = True
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()
            print(f"[UDPServer] Servidor iniciado na porta {self.port}.")
        except Exception as e:
            self.is_running = False
            if self.sock:
                try:
                    self.sock.close()
                except Exception:
                    pass
                self.sock = None
            raise e

    def _run_loop(self):
        while self.is_running:
            try:
                data, addr = self.sock.recvfrom(1024)
            except socket.timeout:
                continue
            except OSError:
                break
            except Exception:
                continue

            try:
                message = json.loads(data.decode('utf-8'))
                key = message.get('key')
                action = message.get('action')

                if key and action:
                    key = str(key).lower()
                    if action == 'down':
                        self.input_ctrl.press(key)
                    elif action == 'up':
                        self.input_ctrl.release(key)
                    elif action == 'tap':
                        self.input_ctrl.press(key)
                        self.input_ctrl.release(key)

                    self.commands_count += 1
                    timestamp = time.strftime("%H:%M:%S")
                    self.last_command = f"[{timestamp}] {key.upper()} ({action.capitalize()})"
                    print(f"[{addr[0]}] {self.last_command}")
                    if self.on_event:
                        self.on_event(addr[0], key, action)
            except Exception as e:
                print(f"[UDPServer] Erro ao processar comando: {e}")

    def stop(self):
        if not self.is_running:
            return
        self.is_running = False
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=1.0)
        self._thread = None
        self.input_ctrl.close()
        print("[UDPServer] Servidor pausado/desligado.")


# -------------------------------------------------------------
# GERAÇÃO DO ÍCONE DA BANDEJA (SYSTEM TRAY)
# -------------------------------------------------------------
def create_tray_image(active=True):
    """Gera um ícone de alta visibilidade e contraste estilo teclado Stream Deck (64x64 RGBA)."""
    if not PIL_AVAILABLE:
        return None
    size = 64
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    border_color = (46, 204, 113, 255) if active else (231, 76, 60, 255)
    bg_color = (24, 26, 34, 255)

    # Contorno arredondado estilo chassi do Stream Deck
    draw.rounded_rectangle([3, 3, 61, 61], radius=14, fill=bg_color, outline=border_color, width=5)

    # 4 botões de atalho internos com alto contraste para visibilidade nítida na bandeja
    key_color = (255, 255, 255, 255) if active else (180, 180, 180, 255)
    draw.rounded_rectangle([13, 13, 27, 27], radius=3, fill=key_color)
    draw.rounded_rectangle([37, 13, 51, 27], radius=3, fill=key_color)
    draw.rounded_rectangle([13, 37, 27, 51], radius=3, fill=key_color)
    draw.rounded_rectangle([37, 37, 51, 51], radius=3, fill=key_color)

    return img


# -------------------------------------------------------------
# INTERFACE GRÁFICA MODERNA (TKINTER + SYSTEM TRAY)
# -------------------------------------------------------------
class StreamDeckGUI:
    """Interface moderna, intuitiva e escura para controle do Servidor Host."""
    def __init__(self, server: UDPServer, start_minimized=False):
        self.server = server
        self.start_minimized = start_minimized
        self.tray_icon = None
        self.local_ip = get_local_ip()

        self.root = tk.Tk()
        if self.start_minimized:
            self.root.withdraw()
        self.root.title("Stream Deck Companion Host")
        self.root.geometry("460x570")
        self.root.resizable(False, False)
        self.root.configure(bg="#14161f")

        # Define ícone da janela
        self._set_window_icon()

        # Vincula callbacks do servidor à thread da interface gráfica
        self.server.on_event = self._on_server_packet_received

        # Intercepta eventos de fechar e minimizar da janela
        self.root.protocol("WM_DELETE_WINDOW", self.on_close_button)

        self._build_ui()
        self._init_tray()

        # Inicia o servidor automaticamente ao abrir
        self._start_server()

        if self.start_minimized:
            # Se iniciado minimizado (startup do Windows)
            self.root.after(300, self.minimize_to_tray)

    def _set_window_icon(self):
        # Tenta carregar ícone .ico local ou PhotoImage
        ico_path = os.path.join(os.path.dirname(__file__), "icon_active.ico")
        if os.path.isfile(ico_path):
            try:
                self.root.iconbitmap(ico_path)
                return
            except Exception:
                pass

        if PIL_AVAILABLE:
            try:
                icon_img = create_tray_image(True)
                self.tk_icon = ImageTk.PhotoImage(icon_img)
                self.root.iconphoto(False, self.tk_icon)
            except Exception:
                pass

    def _build_ui(self):
        # 1. Cabeçalho
        header = tk.Frame(self.root, bg="#1c1f2c", pady=14, padx=16)
        header.pack(fill="x", padx=12, pady=(12, 8))

        title_frame = tk.Frame(header, bg="#1c1f2c")
        title_frame.pack(fill="x")

        tk.Label(
            title_frame,
            text="STREAM DECK HOST",
            font=("Segoe UI", 15, "bold"),
            fg="#ffffff",
            bg="#1c1f2c"
        ).pack(side="left")

        # Badge de Administrador
        is_admin = check_windows_admin()
        admin_text = "ADMIN" if is_admin else "NORMAL"
        admin_fg = "#2ecc71" if is_admin else "#f39c12"
        tk.Label(
            title_frame,
            text=admin_text,
            font=("Segoe UI", 9, "bold"),
            fg=admin_fg,
            bg="#272b3c",
            padx=8,
            pady=2
        ).pack(side="right")

        tk.Label(
            header,
            text="Injeção nativa de hardware / DirectInput para PC",
            font=("Segoe UI", 9),
            fg="#8f95a8",
            bg="#1c1f2c"
        ).pack(anchor="w", pady=(3, 0))

        # 2. Card de Status e Controle Ligar/Desligar
        status_card = tk.Frame(self.root, bg="#1e2230", padx=16, pady=12, highlightbackground="#2d3246", highlightthickness=1)
        status_card.pack(fill="x", padx=12, pady=6)

        status_row = tk.Frame(status_card, bg="#1e2230")
        status_row.pack(fill="x")

        self.status_dot = tk.Label(status_row, text="●", font=("Segoe UI", 16), fg="#2ecc71", bg="#1e2230")
        self.status_dot.pack(side="left")

        self.status_text = tk.Label(
            status_row,
            text=f"SERVIDOR ATIVO (Porta {self.server.port})",
            font=("Segoe UI", 11, "bold"),
            fg="#ffffff",
            bg="#1e2230"
        )
        self.status_text.pack(side="left", padx=(8, 0))

        # Indicador de estado da bandeja
        self.tray_indicator_label = tk.Label(
            status_card,
            text="Conectando à bandeja do sistema...",
            font=("Segoe UI", 8),
            fg="#8f95a8",
            bg="#1e2230"
        )
        self.tray_indicator_label.pack(anchor="w", pady=(4, 0))

        # Botão principal de Ligar / Desligar
        self.toggle_btn = tk.Button(
            status_card,
            text="⏹ Desligar Servidor",
            font=("Segoe UI", 11, "bold"),
            bg="#c0392b",
            fg="#ffffff",
            activebackground="#e74c3c",
            activeforeground="#ffffff",
            relief="flat",
            cursor="hand2",
            pady=8,
            command=self.toggle_server
        )
        self.toggle_btn.pack(fill="x", pady=(10, 0))

        # 3. Card do IP do Computador
        ip_card = tk.Frame(self.root, bg="#1e2230", padx=16, pady=12, highlightbackground="#2d3246", highlightthickness=1)
        ip_card.pack(fill="x", padx=12, pady=6)

        tk.Label(
            ip_card,
            text="ENDEREÇO IP DO COMPUTADOR (IPv4)",
            font=("Segoe UI", 9, "bold"),
            fg="#8f95a8",
            bg="#1e2230"
        ).pack(anchor="w")

        ip_row = tk.Frame(ip_card, bg="#1e2230")
        ip_row.pack(fill="x", pady=(6, 4))

        self.ip_label = tk.Label(
            ip_row,
            text=self.local_ip,
            font=("Consolas", 18, "bold"),
            fg="#5dade2",
            bg="#1e2230"
        )
        self.ip_label.pack(side="left")

        self.copy_btn = tk.Button(
            ip_row,
            text="📋 Copiar",
            font=("Segoe UI", 9, "bold"),
            bg="#2c3e50",
            fg="#ffffff",
            activebackground="#34495e",
            activeforeground="#ffffff",
            relief="flat",
            cursor="hand2",
            padx=10,
            pady=3,
            command=self.copy_ip
        )
        self.copy_btn.pack(side="right", padx=(6, 0))

        self.refresh_btn = tk.Button(
            ip_row,
            text="🔄",
            font=("Segoe UI", 9),
            bg="#2c3e50",
            fg="#ffffff",
            activebackground="#34495e",
            activeforeground="#ffffff",
            relief="flat",
            cursor="hand2",
            padx=8,
            pady=3,
            command=self.refresh_ip
        )
        self.refresh_btn.pack(side="right")

        tk.Label(
            ip_card,
            text="Insira este IP no aplicativo do celular para conectar instantaneamente.",
            font=("Segoe UI", 8, "italic"),
            fg="#70768c",
            bg="#1e2230"
        ).pack(anchor="w")

        # 4. Card de Inicialização Automática e Monitor
        config_card = tk.Frame(self.root, bg="#1e2230", padx=16, pady=12, highlightbackground="#2d3246", highlightthickness=1)
        config_card.pack(fill="x", padx=12, pady=6)

        self.autostart_var = tk.BooleanVar(value=is_autostart_enabled())
        autostart_state = "normal" if sys.platform == "win32" and winreg else "disabled"
        autostart_label = "Iniciar com o Windows (inicia minimizado)" if sys.platform == "win32" else "Iniciar com o sistema (apenas Windows)"

        self.autostart_cb = tk.Checkbutton(
            config_card,
            text=autostart_label,
            variable=self.autostart_var,
            font=("Segoe UI", 10),
            fg="#ffffff",
            bg="#1e2230",
            selectcolor="#14161f",
            activebackground="#1e2230",
            activeforeground="#ffffff",
            cursor="hand2",
            state=autostart_state,
            command=self.on_autostart_toggle
        )
        self.autostart_cb.pack(anchor="w")

        # Separador fino
        tk.Frame(config_card, bg="#2d3246", height=1).pack(fill="x", pady=8)

        # Monitor de Atividade
        log_row = tk.Frame(config_card, bg="#1e2230")
        log_row.pack(fill="x")

        tk.Label(
            log_row,
            text="Último comando:",
            font=("Segoe UI", 9, "bold"),
            fg="#8f95a8",
            bg="#1e2230"
        ).pack(side="left")

        self.cmd_label = tk.Label(
            log_row,
            text="Nenhum ainda",
            font=("Consolas", 9, "bold"),
            fg="#f1c40f",
            bg="#1e2230"
        )
        self.cmd_label.pack(side="left", padx=(8, 0))

        self.count_label = tk.Label(
            log_row,
            text="Total: 0",
            font=("Segoe UI", 9),
            fg="#8f95a8",
            bg="#1e2230"
        )
        self.count_label.pack(side="right")

        # 5. Barra Inferior de Ações
        bottom_frame = tk.Frame(self.root, bg="#14161f", pady=8)
        bottom_frame.pack(fill="x", padx=12, side="bottom")

        tk.Button(
            bottom_frame,
            text="⬇ Minimizar para Ícones Ocultos",
            font=("Segoe UI", 9, "bold"),
            bg="#252a3d",
            fg="#ffffff",
            activebackground="#303750",
            activeforeground="#ffffff",
            relief="flat",
            cursor="hand2",
            padx=12,
            pady=6,
            command=self.minimize_to_tray
        ).pack(side="left", fill="x", expand=True, padx=(0, 6))

        tk.Button(
            bottom_frame,
            text="✕ Sair",
            font=("Segoe UI", 9, "bold"),
            bg="#252a3d",
            fg="#e74c3c",
            activebackground="#303750",
            activeforeground="#ff6b6b",
            relief="flat",
            cursor="hand2",
            padx=16,
            pady=6,
            command=self.quit_application
        ).pack(side="right")

    def _init_tray(self):
        """Inicializa o ícone da bandeja do sistema (system tray)."""
        if not PYSTRAY_AVAILABLE or not PIL_AVAILABLE:
            self.tray_icon = None
            self.tray_indicator_label.config(
                text="[Aviso] Bandeja indisponível (minimizará na barra de tarefas)",
                fg="#f39c12"
            )
            return

        menu = pystray.Menu(
            pystray.MenuItem("Abrir Painel", self.show_window, default=True),
            pystray.MenuItem(
                lambda item: "⏹ Desligar Servidor" if self.server.is_running else "▶ Ligar Servidor",
                self._tray_toggle_server
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Sair", self.quit_application)
        )

        icon_image = create_tray_image(self.server.is_running)
        self.tray_icon = pystray.Icon("stream_deck_host", icon_image, "Stream Deck Host", menu)

        try:
            # run_detached integra o loop de eventos da bandeja sem bloquear o Tkinter
            self.tray_icon.run_detached()
            self.tray_indicator_label.config(
                text="[Ativo] Ícone presente na bandeja de ícones ocultos (^)",
                fg="#2ecc71"
            )
        except Exception as e:
            print(f"[ERRO] Falha ao iniciar ícone da bandeja: {e}")
            self.tray_icon = None
            self.tray_indicator_label.config(
                text="[Aviso] Falha ao registrar na bandeja (minimizará na barra de tarefas)",
                fg="#f39c12"
            )

    def _update_tray_icon(self):
        if self.tray_icon:
            try:
                self.tray_icon.icon = create_tray_image(self.server.is_running)
                status_str = "Ativo" if self.server.is_running else "Parado"
                self.tray_icon.title = f"Stream Deck Host ({status_str})"
            except Exception:
                pass

    def _start_server(self):
        try:
            self.server.start()
            self._update_ui_server_state(True)
        except Exception as e:
            self._update_ui_server_state(False)
            messagebox.showerror("Erro ao Iniciar", f"Não foi possível iniciar o servidor na porta {self.server.port}:\n{e}")

    def _stop_server(self):
        self.server.stop()
        self._update_ui_server_state(False)

    def toggle_server(self):
        if self.server.is_running:
            self._stop_server()
        else:
            self._start_server()

    def _tray_toggle_server(self, icon=None, item=None):
        self.root.after(0, self.toggle_server)

    def _update_ui_server_state(self, running: bool):
        if running:
            self.status_dot.config(text="●", fg="#2ecc71")
            self.status_text.config(text=f"SERVIDOR ATIVO (Porta {self.server.port})", fg="#ffffff")
            self.toggle_btn.config(text="⏹ Desligar Servidor", bg="#c0392b", activebackground="#e74c3c")
        else:
            self.status_dot.config(text="○", fg="#e74c3c")
            self.status_text.config(text="SERVIDOR DESLIGADO", fg="#a0a5b8")
            self.toggle_btn.config(text="▶ Ligar Servidor", bg="#27ae60", activebackground="#2ecc71")

        self._update_tray_icon()

    def _on_server_packet_received(self, ip: str, key: str, action: str):
        # Atualiza a UI na thread do Tkinter
        self.root.after(0, self._update_packet_labels, key, action)

    def _update_packet_labels(self, key: str, action: str):
        self.cmd_label.config(text=f"{key.upper()} ({action})")
        self.count_label.config(text=f"Total: {self.server.commands_count}")

    def copy_ip(self):
        self.root.clipboard_clear()
        self.root.clipboard_append(self.local_ip)
        self.copy_btn.config(text="✓ Copiado!", bg="#27ae60")
        self.root.after(1500, lambda: self.copy_btn.config(text="📋 Copiar", bg="#2c3e50"))

    def refresh_ip(self):
        self.local_ip = get_local_ip()
        self.ip_label.config(text=self.local_ip)

    def on_autostart_toggle(self):
        enabled = self.autostart_var.get()
        success = set_autostart(enabled)
        if not success:
            self.autostart_var.set(not enabled)
            messagebox.showwarning("Aviso", "Não foi possível atualizar a chave de inicialização no Registro do Windows.")

    def minimize_to_tray(self):
        """Oculta a janela principal e a transfere para a bandeja do sistema."""
        if self.tray_icon and getattr(self.tray_icon, "visible", False):
            self.root.withdraw()
            try:
                self.tray_icon.notify(
                    "O servidor continua ativo na bandeja.\nClique duas vezes no ícone ou escolha 'Abrir Painel' para reabrir.",
                    "Stream Deck Companion Host"
                )
            except Exception:
                pass
        else:
            # Fallback de segurança: se a bandeja não estiver ativa, NÃO faça withdraw!
            # Minimize na barra de tarefas normal para que a janela nunca seja perdida
            self.root.iconify()
            messagebox.showinfo(
                "Bandeja do Sistema",
                "A bandeja do sistema não está disponível neste ambiente Python.\n"
                "A janela foi minimizada na barra de tarefas comum para permitir reabertura."
            )

    def on_close_button(self):
        """Ao clicar no 'X', minimiza para a bandeja se disponível, ou fecha."""
        if self.tray_icon and getattr(self.tray_icon, "visible", False):
            self.minimize_to_tray()
        else:
            self.quit_application()

    def show_window(self, icon=None, item=None):
        """Restaura a janela para o primeiro plano."""
        self.root.after(0, self._restore_window)

    def _restore_window(self):
        self.root.deiconify()
        self.root.state("normal")
        self.root.lift()
        self.root.attributes("-topmost", True)
        self.root.after_idle(self.root.attributes, "-topmost", False)
        self.root.focus_force()

    def quit_application(self, icon=None, item=None):
        """Encerra completamente o servidor e a aplicação."""
        self.server.stop()
        if self.tray_icon:
            try:
                self.tray_icon.stop()
            except Exception:
                pass
            self.tray_icon = None
        self.root.after(0, self.root.destroy)

    def run(self):
        self.root.mainloop()


# -------------------------------------------------------------
# PONTO DE ENTRADA DO PROGRAMA
# -------------------------------------------------------------
def start_server_cli(host=HOST, port=PORT):
    """Modo CLI clássico sem interface gráfica."""
    server = UDPServer(host=host, port=port)
    server.start()

    print("=================================================")
    print(f" Servidor UDP iniciado em {host}:{port}")
    if server.input_ctrl.mode == "windows":
        is_admin = check_windows_admin()
        print(" [MODO WINDOWS]: Injeção nativa SendInput (DirectInput) ATIVA")
        if is_admin:
            print(" [ADMIN]: Executando com privilégios de Administrador.")
        else:
            print(" [AVISO]: Executando como usuário comum.")
    elif server.input_ctrl.mode == "linux_x11":
        print(" [MODO LINUX X11]: Injeção de Teclas Extras F13-F24 ATIVA")
    print(f" [IP LOCAL]: {get_local_ip()}")
    print("=================================================")
    print("Pressione CTRL+C para encerrar.\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nEncerrando servidor...")
    finally:
        server.stop()


def start_server(host=HOST, port=PORT):
    """Função legada para compatibilidade retroativa."""
    start_server_cli(host=host, port=port)


def main():
    parser = argparse.ArgumentParser(description="Stream Deck Companion Host Server")
    parser.add_argument("--cli", action="store_true", help="Executa no terminal sem interface gráfica")
    parser.add_argument("--minimized", action="store_true", help="Inicia o servidor minimizado na bandeja do sistema")
    parser.add_argument("--host", default=HOST, help="Endereço IP de escuta (padrão: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=PORT, help="Porta UDP (padrão: 8080)")
    args = parser.parse_args()

    # Se estiver no Windows e executando pelo GUI, garante interpretador com todas as dependências
    if not args.cli:
        ensure_correct_python_environment()

    # Se explicitamente solicitado modo CLI ou se Tkinter não estiver disponível
    if args.cli or not TK_AVAILABLE:
        start_server_cli(host=args.host, port=args.port)
    else:
        server = UDPServer(host=args.host, port=args.port)
        gui = StreamDeckGUI(server=server, start_minimized=args.minimized)
        gui.run()


if __name__ == "__main__":
    main()
