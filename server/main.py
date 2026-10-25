import socket
import json
import sys
import os

# Configurações do servidor UDP
HOST = '0.0.0.0'
PORT = 8080

class InputController:
    """
    Controlador universal de entrada de teclado:
    - No Windows: Utiliza pydirectinput (DirectInput scancodes) para compatibilidade com jogos (DirectX/OpenGL).
    - No Linux: Utiliza a API nativa X11 / libXtst (XTestFakeKeyEvent) para injeção real de hardware no sistema.
    """
    def __init__(self):
        self.mode = "none"
        self._init_backend()

    def _init_backend(self):
        # 1. Windows: DirectInput via pydirectinput
        if sys.platform.startswith('win'):
            try:
                import pydirectinput
                pydirectinput.PAUSE = 0.0
                self.pydirectinput = pydirectinput
                self.mode = "windows_directinput"
                return
            except ImportError:
                print("AVISO [Windows]: 'pydirectinput' não está instalado.")
                print("Execute: pip install -r requirements.txt")

        # 2. Linux: X11 via libXtst / libX11 (nativo do sistema, sem precisar de pacotes extras)
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
                        'shift_l': b'Shift_L',
                        'shift_r': b'Shift_R',
                        'ctrl': b'Control_L',
                        'ctrl_l': b'Control_L',
                        'ctrl_r': b'Control_R',
                        'control': b'Control_L',
                        'alt': b'Alt_L',
                        'alt_l': b'Alt_L',
                        'alt_r': b'Alt_R',
                        'up': b'Up',
                        'down': b'Down',
                        'left': b'Left',
                        'right': b'Right',
                    }
                    return
            except Exception as e:
                print(f"AVISO [Linux]: Não foi possível inicializar injeção X11: {e}")

        self.mode = "log_only"

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
        if self.mode == "windows_directinput":
            self.pydirectinput.keyDown(key_str)
        elif self.mode == "linux_x11":
            code = self._get_x11_keycode(key_str)
            if code:
                self.xtst.XTestFakeKeyEvent(self.display, code, 1, 0)
                self.x11.XFlush(self.display)

    def release(self, key_str):
        if self.mode == "windows_directinput":
            self.pydirectinput.keyUp(key_str)
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
    if input_ctrl.mode == "windows_directinput":
        print(" [MODO WINDOWS]: Injeção DirectInput ATIVA (jogos e sistema)")
    elif input_ctrl.mode == "linux_x11":
        print(" [MODO LINUX X11]: Injeção de hardware X11 ATIVA (jogos e sistema)")
    else:
        print(" [MODO SOMENTE LOG]: Injeção no sistema desativada")
    print("=================================================")
    print("Aguardando comandos do aplicativo...")
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
                        print(f"[{addr[0]}] TECLA PRESSIONADA (Down) : {key}")
                    elif action == 'up':
                        input_ctrl.release(key)
                        print(f"[{addr[0]}] TECLA SOLTA (Up)       : {key}")
                        
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

