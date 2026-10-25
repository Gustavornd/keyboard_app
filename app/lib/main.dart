import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StreamDeckApp());
}

class StreamDeckApp extends StatelessWidget {
  const StreamDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Deck Extra Keys',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurpleAccent,
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
  String _serverIp = '192.168.1.100';
  final int _serverPort = 8080;
  RawDatagramSocket? _udpSocket;
  final Set<String> _pressedKeys = {};

  // 12 botões independentes vinculados às teclas de hardware F13 até F24
  final List<Map<String, dynamic>> _buttons = [
    {'id': 'f13', 'defaultLabel': 'Botão 1', 'sub': 'F13', 'color': Colors.blueAccent},
    {'id': 'f14', 'defaultLabel': 'Botão 2', 'sub': 'F14', 'color': Colors.cyanAccent},
    {'id': 'f15', 'defaultLabel': 'Botão 3', 'sub': 'F15', 'color': Colors.greenAccent},
    {'id': 'f16', 'defaultLabel': 'Botão 4', 'sub': 'F16', 'color': Colors.tealAccent},
    {'id': 'f17', 'defaultLabel': 'Botão 5', 'sub': 'F17', 'color': Colors.amberAccent},
    {'id': 'f18', 'defaultLabel': 'Botão 6', 'sub': 'F18', 'color': Colors.orangeAccent},
    {'id': 'f19', 'defaultLabel': 'Botão 7', 'sub': 'F19', 'color': Colors.deepOrangeAccent},
    {'id': 'f20', 'defaultLabel': 'Botão 8', 'sub': 'F20', 'color': Colors.redAccent},
    {'id': 'f21', 'defaultLabel': 'Botão 9', 'sub': 'F21', 'color': Colors.purpleAccent},
    {'id': 'f22', 'defaultLabel': 'Botão 10', 'sub': 'F22', 'color': Colors.deepPurpleAccent},
    {'id': 'f23', 'defaultLabel': 'Botão 11', 'sub': 'F23', 'color': Colors.indigoAccent},
    {'id': 'f24', 'defaultLabel': 'Botão 12', 'sub': 'F24', 'color': Colors.pinkAccent},
  ];

  final Map<String, String> _customLabels = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initSocket();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('serverIp') ?? '192.168.1.100';
      for (final btn in _buttons) {
        final id = btn['id'] as String;
        final saved = prefs.getString('label_$id');
        if (saved != null && saved.isNotEmpty) {
          _customLabels[id] = saved;
        }
      }
    });
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIp', ip);
    setState(() {
      _serverIp = ip;
    });
  }

  Future<void> _saveButtonLabel(String id, String newLabel) async {
    final prefs = await SharedPreferences.getInstance();
    if (newLabel.trim().isEmpty) {
      await prefs.remove('label_$id');
      setState(() {
        _customLabels.remove(id);
      });
    } else {
      await prefs.setString('label_$id', newLabel.trim());
      setState(() {
        _customLabels[id] = newLabel.trim();
      });
    }
  }

  Future<void> _initSocket() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      debugPrint('Erro ao iniciar socket UDP: $e');
    }
  }

  void _handleKey(String key, String action) {
    if (action == 'down') {
      HapticFeedback.lightImpact();
      setState(() {
        _pressedKeys.add(key);
      });
    } else {
      setState(() {
        _pressedKeys.remove(key);
      });
    }

    if (_udpSocket == null) return;
    try {
      final address = InternetAddress(_serverIp);
      final message = jsonEncode({'key': key, 'action': action});
      final data = utf8.encode(message);
      _udpSocket!.send(data, address, _serverPort);
    } catch (e) {
      debugPrint('Erro ao enviar UDP: $e');
    }
  }

  void _showRenameDialog(String id, String currentLabel, String defaultLabel) {
    final controller = TextEditingController(text: currentLabel == defaultLabel ? '' : currentLabel);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Personalizar Nome ($id)'.toUpperCase()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nome do Botão',
                  hintText: defaultLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deixe em branco para restaurar o nome padrão.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                _saveButtonLabel(id, controller.text);
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _showConfigModal() {
    final TextEditingController ipController = TextEditingController(text: _serverIp);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conexão com o PC'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(
              labelText: 'Endereço IP do Computador',
              hintText: 'ex: 192.168.1.15',
              prefixIcon: Icon(Icons.wifi),
              border: OutlineInputBorder(),
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
        title: const Text('Stream Deck Extra Keys', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigModal,
            tooltip: 'Configurar IP do Computador',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Host PC: $_serverIp:$_serverPort', style: const TextStyle(color: Colors.white70)),
                    const Text('Segure para renomear ✏️', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 colunas para acomodar 12 botões confortavelmente
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _buttons.length,
                  itemBuilder: (context, index) {
                    final btn = _buttons[index];
                    final id = btn['id'] as String;
                    final defaultLabel = btn['defaultLabel'] as String;
                    final displayLabel = _customLabels[id] ?? defaultLabel;
                    final sub = btn['sub'] as String;
                    final color = btn['color'] as Color;
                    final isPressed = _pressedKeys.contains(id);

                    return _buildExtraKeyButton(
                      id: id,
                      label: displayLabel,
                      defaultLabel: defaultLabel,
                      sub: sub,
                      color: color,
                      isPressed: isPressed,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraKeyButton({
    required String id,
    required String label,
    required String defaultLabel,
    required String sub,
    required Color color,
    required bool isPressed,
  }) {
    return GestureDetector(
      onTapDown: (_) => _handleKey(id, 'down'),
      onTapUp: (_) => _handleKey(id, 'up'),
      onTapCancel: () => _handleKey(id, 'up'),
      onLongPress: () => _showRenameDialog(id, label, defaultLabel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        decoration: BoxDecoration(
          color: isPressed ? color.withOpacity(0.4) : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPressed ? Colors.white : color.withOpacity(0.7),
            width: isPressed ? 2.5 : 1.5,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isPressed ? Colors.white : color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

