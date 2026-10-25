import socket
import json
import sys

# Configurações do servidor UDP
HOST = '0.0.0.0'
PORT = 8080

# Tenta carregar pydirectinput (disponível no Windows)
try:
    import pydirectinput
    pydirectinput.PAUSE = 0.0
    DIRECT_INPUT_AVAILABLE = True
except (ImportError, AttributeError, Exception):
    DIRECT_INPUT_AVAILABLE = False

def start_server():
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_socket.bind((HOST, PORT))
    
    print(f"=================================================")
    print(f" Servidor UDP iniciado na porta {PORT}")
    if DIRECT_INPUT_AVAILABLE:
        print(" [MODO WINDOWS]: Injeção DirectInput ATIVA")
    else:
        print(" [MODO TESTE/LINUX]: Injeção desativada (Modo simulação e log ativo)")
        print(" -> As teclas recebidas serão exibidas aqui no terminal.")
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
                        if DIRECT_INPUT_AVAILABLE:
                            pydirectinput.keyDown(key)
                        print(f"[{addr[0]}] TECLA PRESSIONADA (Down) : {key}")
                    elif action == 'up':
                        if DIRECT_INPUT_AVAILABLE:
                            pydirectinput.keyUp(key)
                        print(f"[{addr[0]}] TECLA SOLTA (Up)       : {key}")
                        
            except json.JSONDecodeError:
                print(f"Mensagem inválida recebida de {addr}: {data}")
            except Exception as e:
                print(f"Erro ao processar comando para a tecla '{key}': {e}")
                
    except KeyboardInterrupt:
        print("\nEncerrando servidor...")
    finally:
        server_socket.close()

if __name__ == "__main__":
    start_server()

