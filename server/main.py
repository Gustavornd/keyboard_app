import socket
import json
import sys
import os
import subprocess

# Configurações do servidor UDP
HOST = '0.0.0.0'
PORT = 8080

class InputController:
    """
    Controlador universal de entrada de teclado:
    - No Windows: Suporta teclas padrão via pydirectinput e teclas estendidas F13-F24 / Numpad via Win32 SendInput/keybd_event.
    - No Linux: Suporta teclas padrão, F13-F24 e Numpad via X11 / libXtst (XTestFakeKeyEvent).
    """
    def __init__(self):
        self.mode = "none"
        self._init_backend()

    def _init_backend(self):
        # 1. Configuração Windows
        if sys.platform.startswith('win'):
            self.mode = "windows"
            try:
                import ctypes
                self.user32 = ctypes.windll.user32
            except Exception:
                self.user32 = None

            try:
                import pydirectinput
                pydirectinput.PAUSE = 0.0
                self.pydirectinput = pydirectinput
            except ImportError:
                self.pydirectinput = None
                print("DICA [Windows]: Para jogos em DirectInput, instale: pip install -r requirements.txt")

            # Mapeamento de teclas F13-F24 no Windows (Virtual Key Codes)
            self._win_vk_map = {
                f'f{i}': 0x7C + (i - 13) for i in range(13, 25) # 0x7C (F13) até 0x87 (F24)
            }
            # Mapeamento de Numpad
            for i in range(10):
                self._win_vk_map[f'numpad_{i}'] = 0x60 + i
                self._win_vk_map[f'num_{i}'] = 0x60 + i
            self._win_vk_map['numpad_enter'] = 0x0D
            self._win_vk_map['numpad_add'] = 0x6B
            self._win_vk_map['numpad_sub'] = 0x6D
            self._win_vk_map['numpad_mul'] = 0x6A
            self._win_vk_map['numpad_div'] = 0x6F
            return

        # 2. Configuração Linux (X11)
        if sys.platform.startswith('linux'):
            try:
                import ctypes
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

    def press(self, key_str):
        # Windows
        if self.mode == "windows":
            if key_str in self._win_vk_map and self.user32:
                vk = self._win_vk_map[key_str]
                scan = self.user32.MapVirtualKeyA(vk, 0)
                self.user32.keybd_event(vk, scan, 0, 0)
            elif self.pydirectinput:
                try:
                    self.pydirectinput.keyDown(key_str)
                except Exception:
                    pass
        # Linux
        elif self.mode == "linux_x11":
            code = self._get_x11_keycode(key_str)
            if code:
                self.xtst.XTestFakeKeyEvent(self.display, code, 1, 0)
                self.x11.XFlush(self.display)

    def release(self, key_str):
        # Windows
        if self.mode == "windows":
            if key_str in self._win_vk_map and self.user32:
                vk = self._win_vk_map[key_str]
                scan = self.user32.MapVirtualKeyA(vk, 0)
                self.user32.keybd_event(vk, scan, 2, 0) # 2 = KEYEVENTF_KEYUP
            elif self.pydirectinput:
                try:
                    self.pydirectinput.keyUp(key_str)
                except Exception:
                    pass
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

def start_server():
    input_ctrl = InputController()
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_socket.bind((HOST, PORT))
    
    print("=================================================")
    print(f" Servidor UDP iniciado na porta {PORT}")
    if input_ctrl.mode == "windows":
        print(" [MODO WINDOWS]: Injeção de Teclas F13-F24 e DirectInput ATIVA")
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
                    key = key.lower()
                    
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

