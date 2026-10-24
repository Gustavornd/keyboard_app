import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StreamDeckApp());
}

class StreamDeckApp extends StatelessWidget {
  const StreamDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Deck Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DeckScreen(),
    );
  }
}

class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  String _serverIp = '192.168.1.100'; // IP Padrão
  final int _serverPort = 8080;
  RawDatagramSocket? _udpSocket;

  // Lista de botões configuráveis
  final List<Map<String, dynamic>> _buttons = [
    {'label': 'Acelerar (W)', 'key': 'w', 'color': Colors.green},
    {'label': 'Frear/Re (S)', 'key': 's', 'color': Colors.red},
    {'label': 'Esquerda (A)', 'key': 'a', 'color': Colors.blue},
    {'label': 'Direita (D)', 'key': 'd', 'color': Colors.blue},
    {'label': 'Buzina (H)', 'key': 'h', 'color': Colors.orange},
    {'label': 'Farol (L)', 'key': 'l', 'color': Colors.yellow},
    {'label': 'Freio de Mão (Space)', 'key': 'space', 'color': Colors.redAccent},
    {'label': 'Visão 1 (1)', 'key': '1', 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _loadIp();
    _initSocket();
  }

  Future<void> _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('serverIp') ?? '192.168.1.100';
    });
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIp', ip);
    setState(() {
      _serverIp = ip;
    });
  }

  Future<void> _initSocket() async {
    try {
      // Abre a porta UDP no app para enviar comandos
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      debugPrint('Erro ao iniciar UDP: $e');
    }
  }

  // Função central para envio dos comandos KeyDown e KeyUp
  void _sendCommand(String key, String action) {
    if (_udpSocket == null) return;
    try {
      final address = InternetAddress(_serverIp);
      // Formato JSON compatível com nosso servidor Python
      final message = jsonEncode({'key': key, 'action': action});
      final data = utf8.encode(message);
      
      _udpSocket!.send(data, address, _serverPort);
      debugPrint('Enviado: $message para $_serverIp:$_serverPort');
    } catch (e) {
      debugPrint('Erro ao enviar comando UDP: $e');
    }
  }

  void _showConfigModal() {
    final TextEditingController ipController = TextEditingController(text: _serverIp);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conexão Host (PC)'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(
              labelText: 'Endereço IP do PC na rede',
              hintText: 'ex: 192.168.0.10',
              prefixIcon: Icon(Icons.wifi),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                _saveIp(ipController.text.trim());
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _udpSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Stream Deck', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigModal,
            tooltip: 'Configurar IP do Host',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                'Host atual: $_serverIp',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  // Grid flexível para os botões do Deck
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 colunas
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3, // Formato mais retangular do botão
                  ),
                  itemCount: _buttons.length,
                  itemBuilder: (context, index) {
                    final btn = _buttons[index];
                    return _buildGameButton(btn['label'], btn['key'], btn['color']);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameButton(String label, String keyName, Color color) {
    // GestureDetector é crucial para separar o TapDown (pressionar) do TapUp/Cancel (soltar)
    return GestureDetector(
      onTapDown: (_) => _sendCommand(keyName, 'down'),
      onTapUp: (_) => _sendCommand(keyName, 'up'),
      onTapCancel: () => _sendCommand(keyName, 'up'),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
