import unittest
import socket
import json
import time
import sys
import os
import ctypes

# Import do módulo server
sys.path.insert(0, os.path.dirname(__file__))
from main import (
    INPUT,
    KEYBDINPUT,
    INPUT_KEYBOARD,
    KEYEVENTF_EXTENDEDKEY,
    KEYEVENTF_KEYUP,
    KEYEVENTF_SCANCODE,
    WIN_KEY_CONFIG,
    build_win_input,
    InputController,
    LPINPUT,
    UDPServer,
    get_local_ip,
    create_tray_image,
    is_autostart_enabled,
    set_autostart,
)

class TestServerWin32Structures(unittest.TestCase):
    def test_struct_sizes(self):
        """Verifica se os tamanhos das estruturas Win32 atendem à especificação C ABI."""
        is_64bit = sys.maxsize > 2**32
        expected_input_size = 40 if is_64bit else 28
        expected_kb_size = 24 if is_64bit else 16
        
        self.assertEqual(ctypes.sizeof(INPUT), expected_input_size)
        self.assertEqual(ctypes.sizeof(KEYBDINPUT), expected_kb_size)

    def test_build_win_input_f13(self):
        """F13 deve enviar VK_F13 (0x7C) com scancode OEM 0x64 e SEM KEYEVENTF_SCANCODE."""
        vk, scan, is_ext, use_scan = WIN_KEY_CONFIG['f13']
        self.assertEqual(vk, 0x7C)
        self.assertEqual(scan, 0x64)
        self.assertFalse(is_ext)
        self.assertFalse(use_scan)

        # Press (Down)
        inp_down = build_win_input(vk, scan, is_ext, is_up=False, use_scancode=use_scan)
        self.assertEqual(inp_down.type, INPUT_KEYBOARD)
        self.assertEqual(inp_down.ki.wVk, 0x7C)
        self.assertEqual(inp_down.ki.wScan, 0x64)
        self.assertEqual(inp_down.ki.dwFlags, 0)

        # Release (Up)
        inp_up = build_win_input(vk, scan, is_ext, is_up=True, use_scancode=use_scan)
        self.assertEqual(inp_up.type, INPUT_KEYBOARD)
        self.assertEqual(inp_up.ki.wVk, 0x7C)
        self.assertEqual(inp_up.ki.wScan, 0x64)
        self.assertEqual(inp_up.ki.dwFlags, KEYEVENTF_KEYUP)

    def test_build_win_input_numpad1(self):
        """Numpad 1 deve enviar DirectInput scancode 0x4F com KEYEVENTF_SCANCODE."""
        vk, scan, is_ext, use_scan = WIN_KEY_CONFIG['numpad_1']
        self.assertEqual(vk, 0x61)
        self.assertEqual(scan, 0x4F)
        self.assertFalse(is_ext)
        self.assertTrue(use_scan)

        # Press (Down)
        inp_down = build_win_input(vk, scan, is_ext, is_up=False, use_scancode=use_scan)
        self.assertEqual(inp_down.type, INPUT_KEYBOARD)
        self.assertEqual(inp_down.ki.wVk, 0x61)
        self.assertEqual(inp_down.ki.wScan, 0x4F)
        self.assertEqual(inp_down.ki.dwFlags, KEYEVENTF_SCANCODE)

        # Release (Up)
        inp_up = build_win_input(vk, scan, is_ext, is_up=True, use_scancode=use_scan)
        self.assertEqual(inp_up.type, INPUT_KEYBOARD)
        self.assertEqual(inp_up.ki.wVk, 0x61)
        self.assertEqual(inp_up.ki.wScan, 0x4F)
        self.assertEqual(inp_up.ki.dwFlags, KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP)

    def test_build_win_input_numpad_enter(self):
        """Numpad Enter deve enviar scancode 0x1C com KEYEVENTF_SCANCODE e KEYEVENTF_EXTENDEDKEY."""
        vk, scan, is_ext, use_scan = WIN_KEY_CONFIG['numpad_enter']
        self.assertEqual(scan, 0x1C)
        self.assertTrue(is_ext)
        self.assertTrue(use_scan)

        inp = build_win_input(vk, scan, is_ext, is_up=False, use_scancode=use_scan)
        self.assertEqual(inp.ki.dwFlags, KEYEVENTF_SCANCODE | KEYEVENTF_EXTENDEDKEY)

    def test_all_f_keys_present_and_valid(self):
        """F13 a F24 devem estar mapeados com scancodes válidos e não-nulos."""
        for i in range(13, 25):
            key = f'f{i}'
            self.assertIn(key, WIN_KEY_CONFIG)
            vk, scan, is_ext, use_scan = WIN_KEY_CONFIG[key]
            self.assertEqual(vk, 0x7C + (i - 13))
            self.assertEqual(scan, 0x64 + (i - 13))
            self.assertGreater(scan, 0, f"Scancode de {key} não pode ser zero!")

    def test_all_numpad_keys_present_and_valid(self):
        """Numpad 0 a 9 e operações devem estar mapeados com scancodes válidos."""
        for i in range(10):
            self.assertIn(f'numpad_{i}', WIN_KEY_CONFIG)
            self.assertIn(f'num_{i}', WIN_KEY_CONFIG)
            _, scan, _, use_scan = WIN_KEY_CONFIG[f'numpad_{i}']
            self.assertTrue(use_scan)
            self.assertGreater(scan, 0)

        for op in ['numpad_add', 'numpad_sub', 'numpad_mul', 'numpad_div', 'numpad_enter']:
            self.assertIn(op, WIN_KEY_CONFIG)
            _, scan, _, use_scan = WIN_KEY_CONFIG[op]
            self.assertTrue(use_scan)
            self.assertGreater(scan, 0)

    def test_mock_windows_injection(self):
        """Simula a injeção em ambiente Windows via mock de user32.SendInput."""
        ctrl = InputController()
        ctrl.mode = "windows"
        
        captured_inputs = []
        
        @ctypes.CFUNCTYPE(ctypes.c_uint, ctypes.c_uint, LPINPUT, ctypes.c_int)
        def mock_send_input(count, pInputs, cbSize):
            captured_inputs.append((
                count,
                pInputs.contents.ki.wVk,
                pInputs.contents.ki.wScan,
                pInputs.contents.ki.dwFlags,
                cbSize
            ))
            return 1

        class MockUser32:
            SendInput = mock_send_input

        ctrl.user32 = MockUser32()
        is_64bit = sys.maxsize > 2**32
        expected_size = 40 if is_64bit else 28
        
        # Teste F13 press e release
        ctrl.press('f13')
        ctrl.release('f13')
        self.assertEqual(len(captured_inputs), 2)
        # Down: count=1, vk=0x7C, scan=0x64, dwFlags=0, size=40
        self.assertEqual(captured_inputs[0], (1, 0x7C, 0x64, 0, expected_size))
        # Up: count=1, vk=0x7C, scan=0x64, dwFlags=KEYEVENTF_KEYUP, size=40
        self.assertEqual(captured_inputs[1], (1, 0x7C, 0x64, KEYEVENTF_KEYUP, expected_size))

        # Teste Numpad 1 press e release
        captured_inputs.clear()
        ctrl.press('numpad_1')
        ctrl.release('numpad_1')
        self.assertEqual(len(captured_inputs), 2)
        # Down: count=1, vk=0x61, scan=0x4F, dwFlags=KEYEVENTF_SCANCODE
        self.assertEqual(captured_inputs[0], (1, 0x61, 0x4F, KEYEVENTF_SCANCODE, expected_size))
        # Up: count=1, vk=0x61, scan=0x4F, dwFlags=KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP
        self.assertEqual(captured_inputs[1], (1, 0x61, 0x4F, KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP, expected_size))

    def test_media_keys_present_and_valid(self):
        """Teclas de mídia devem estar configuradas no WIN_KEY_CONFIG."""
        media_keys = [
            'media_play_pause', 'play_pause', 'media_next', 'next_track',
            'media_prev', 'prev_track', 'media_stop', 'volume_mute',
            'volume_up', 'volume_down'
        ]
        for mk in media_keys:
            self.assertIn(mk, WIN_KEY_CONFIG)
            vk, scan, is_ext, use_scan = WIN_KEY_CONFIG[mk]
            self.assertGreater(vk, 0)
            self.assertTrue(is_ext, f"{mk} deve ter is_extended=True")
            self.assertFalse(use_scan, f"{mk} não deve ter use_scancode=True")

    def test_mock_send_input_failure_does_not_crash(self):
        """Verifica se falha de SendInput não causa AttributeError por GetLastError."""
        ctrl = InputController()
        ctrl.mode = "windows"
        
        @ctypes.CFUNCTYPE(ctypes.c_uint, ctypes.c_uint, LPINPUT, ctypes.c_int)
        def failing_send_input(count, pInputs, cbSize):
            return 0  # Falha

        class MockUser32:
            SendInput = failing_send_input

        ctrl.user32 = MockUser32()
        # Não deve levantar exceção mesmo com retorno de erro do SendInput
        ctrl.press('f13')
        ctrl.release('f13')

    def test_minimum_hold_duration(self):
        """Garante que release() aguarde pelo menos 50ms após press() para evitar drop em jogos."""
        ctrl = InputController()
        ctrl.mode = "none"
        start = time.time()
        ctrl.press('f13')
        ctrl.release('f13')
        elapsed = time.time() - start
        self.assertGreaterEqual(elapsed, 0.048, "Key press deve durar pelo menos ~50ms")

    def test_navigation_keys(self):
        """Verifica se teclas de navegação estão mapeadas para uso em jogos/mods."""
        nav_keys = ['insert', 'delete', 'home', 'end', 'pageup', 'pagedown', 'scroll_lock', 'pause']
        for k in nav_keys:
            self.assertIn(k, WIN_KEY_CONFIG)
            vk, scan, is_ext, use_scan = WIN_KEY_CONFIG[k]
            self.assertTrue(use_scan, f"{k} deve usar scancode de hardware")
            self.assertGreater(scan, 0)

    def test_udp_message_handling(self):
        """Testa o processamento de pacotes UDP com ações down, up e tap."""
        import threading
        
        calls = []
        class MockController:
            def press(self, k):
                calls.append(('press', k))
            def release(self, k):
                calls.append(('release', k))
            def close(self):
                pass

        mock_ctrl = MockController()
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
        sock.settimeout(0.5)

        stop_event = threading.Event()

        def server_loop():
            while not stop_event.is_set():
                try:
                    data, addr = sock.recvfrom(1024)
                    msg = json.loads(data.decode('utf-8'))
                    key = msg.get('key', '').lower()
                    action = msg.get('action')
                    if action == 'down':
                        mock_ctrl.press(key)
                    elif action == 'up':
                        mock_ctrl.release(key)
                    elif action == 'tap':
                        mock_ctrl.press(key)
                        mock_ctrl.release(key)
                except socket.timeout:
                    continue
                except Exception:
                    break

        t = threading.Thread(target=server_loop)
        t.start()

        client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        client.sendto(json.dumps({'key': 'F13', 'action': 'down'}).encode(), ('127.0.0.1', port))
        client.sendto(json.dumps({'key': 'F13', 'action': 'up'}).encode(), ('127.0.0.1', port))
        client.sendto(json.dumps({'key': 'NUMPAD_1', 'action': 'tap'}).encode(), ('127.0.0.1', port))
        
        time.sleep(0.15)
        stop_event.set()
        t.join(timeout=1.0)
        sock.close()
        client.close()

        self.assertEqual(calls, [
            ('press', 'f13'),
            ('release', 'f13'),
            ('press', 'numpad_1'),
            ('release', 'numpad_1'),
        ])

    def test_get_local_ip(self):
        """Verifica se get_local_ip retorna um endereço IPv4 válido."""
        ip = get_local_ip()
        self.assertIsInstance(ip, str)
        parts = ip.split('.')
        self.assertEqual(len(parts), 4)
        for p in parts:
            self.assertTrue(p.isdigit())
            self.assertTrue(0 <= int(p) <= 255)

    def test_udp_server_lifecycle(self):
        """Testa inicialização, envio de pacotes e encerramento do UDPServer."""
        received = []
        def on_event(ip, key, action):
            received.append((ip, key, action))

        # Usa porta 0 para alocação dinâmica pelo SO
        server = UDPServer(host='127.0.0.1', port=0, on_event=on_event)
        server.start()
        self.assertTrue(server.is_running)
        self.assertIsNotNone(server.sock)
        actual_port = server.sock.getsockname()[1]

        # Envia comando de teste
        client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        client.sendto(json.dumps({'key': 'F14', 'action': 'down'}).encode('utf-8'), ('127.0.0.1', actual_port))
        time.sleep(0.1)

        server.stop()
        client.close()
        self.assertFalse(server.is_running)
        self.assertIsNone(server.sock)
        self.assertEqual(len(received), 1)
        self.assertEqual(received[0][1], 'f14')
        self.assertEqual(received[0][2], 'down')

    def test_create_tray_image(self):
        """Testa geração do ícone da bandeja em estados ativo e inativo."""
        img_active = create_tray_image(active=True)
        img_inactive = create_tray_image(active=False)
        self.assertIsNotNone(img_active)
        self.assertIsNotNone(img_inactive)
        self.assertEqual(img_active.size, (64, 64))
        self.assertEqual(img_inactive.size, (64, 64))

    def test_autostart_registry_toggle(self):
        """Verifica integridade de leitura e escrita do autostart no Windows."""
        if sys.platform != 'win32':
            self.skipTest('Teste de registro exclusivo para Windows')

        initial_state = is_autostart_enabled()
        try:
            self.assertTrue(set_autostart(not initial_state))
            self.assertEqual(is_autostart_enabled(), not initial_state)
        finally:
            set_autostart(initial_state)
            self.assertEqual(is_autostart_enabled(), initial_state)

if __name__ == '__main__':
    unittest.main()
