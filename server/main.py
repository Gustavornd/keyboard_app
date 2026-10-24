import socket
import json
import pydirectinput

# Configurações do servidor UDP
HOST = '0.0.0.0'
PORT = 8080

def start_server():
    # Remove o tempo de pausa (delay) padrão entre os comandos do pydirectinput
    # Isso garante que a injeção seja instantânea para uma melhor experiência (baixa latência)
    pydirectinput.PAUSE = 0.0

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server_socket.bind((HOST, PORT))
    
    print(f"Servidor UDP iniciado na porta {PORT}.")
    print("Aguardando comandos do aplicativo...")
    print("-------------------------------------------------")
    print("DICA: Certifique-se de permitir o Python e esta porta no Firewall do Windows!")
    print("Para sair, pressione CTRL+C.")
    
    try:
        while True:
            data, addr = server_socket.recvfrom(1024)
            try:
                message = json.loads(data.decode('utf-8'))
                key = message.get('key')
                action = message.get('action')
                
                if key and action:
                    key = key.lower() # O pydirectinput usa teclas em minúsculo, ex: 'w', 'shift', 'space'
                    
                    if action == 'down':
                        pydirectinput.keyDown(key)
                        print(f"[{addr[0]}] TECLA PRESSIONADA (Down) : {key}")
                    elif action == 'up':
                        pydirectinput.keyUp(key)
                        print(f"[{addr[0]}] TECLA SOLTA (Up)       : {key}")
                        
            except json.JSONDecodeError:
                print(f"Mensagem inválida recebida de {addr}: {data}")
            except Exception as e:
                # Caso venha uma tecla não mapeada ou ocorra erro
                print(f"Erro ao processar comando para a tecla '{key}': {e}")
                
    except KeyboardInterrupt:
        print("\nEncerrando servidor...")
    finally:
        server_socket.close()

if __name__ == "__main__":
    start_server()
