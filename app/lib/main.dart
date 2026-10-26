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

enum DeckMode {
  fKeys,   // F13 a F24 (Streamlabs / OBS em background - sem conflito com jogos)
  numpad,  // Numpad Extra (Minecraft / Jogos em DirectInput)
  nav,     // Navegação / Mods (Insert, Delete, PageUp, PageDown, etc.)
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
  DeckMode _currentMode = DeckMode.fKeys;

  // Modo F13 até F24: Perfeito para Streamlabs / OBS em background sem colidir com jogos
  static const List<Map<String, dynamic>> _fKeysButtons = [
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

  // Modo Numpad: Reconhecido nativamente por DirectInput (Minecraft Java, ETS2, Flight Sim)
  static const List<Map<String, dynamic>> _numpadButtons = [
    {'id': 'numpad_1', 'defaultLabel': 'Botão 1', 'sub': 'Num 1', 'color': Colors.blueAccent},
    {'id': 'numpad_2', 'defaultLabel': 'Botão 2', 'sub': 'Num 2', 'color': Colors.cyanAccent},
    {'id': 'numpad_3', 'defaultLabel': 'Botão 3', 'sub': 'Num 3', 'color': Colors.greenAccent},
    {'id': 'numpad_4', 'defaultLabel': 'Botão 4', 'sub': 'Num 4', 'color': Colors.tealAccent},
    {'id': 'numpad_5', 'defaultLabel': 'Botão 5', 'sub': 'Num 5', 'color': Colors.amberAccent},
    {'id': 'numpad_6', 'defaultLabel': 'Botão 6', 'sub': 'Num 6', 'color': Colors.orangeAccent},
    {'id': 'numpad_7', 'defaultLabel': 'Botão 7', 'sub': 'Num 7', 'color': Colors.deepOrangeAccent},
    {'id': 'numpad_8', 'defaultLabel': 'Botão 8', 'sub': 'Num 8', 'color': Colors.redAccent},
    {'id': 'numpad_9', 'defaultLabel': 'Botão 9', 'sub': 'Num 9', 'color': Colors.purpleAccent},
    {'id': 'numpad_0', 'defaultLabel': 'Botão 10', 'sub': 'Num 0', 'color': Colors.deepPurpleAccent},
    {'id': 'numpad_add', 'defaultLabel': 'Botão 11', 'sub': 'Num +', 'color': Colors.indigoAccent},
    {'id': 'numpad_enter', 'defaultLabel': 'Botão 12', 'sub': 'Num Enter', 'color': Colors.pinkAccent},
  ];

  // Modo Navegação / Mods: Insert, Delete, PageUp, PageDown para gerenciamento de mods no Minecraft
  static const List<Map<String, dynamic>> _navButtons = [
    {'id': 'insert', 'defaultLabel': 'Botão 1', 'sub': 'Insert', 'color': Colors.blueAccent},
    {'id': 'delete', 'defaultLabel': 'Botão 2', 'sub': 'Delete', 'color': Colors.cyanAccent},
    {'id': 'pageup', 'defaultLabel': 'Botão 3', 'sub': 'PageUp', 'color': Colors.greenAccent},
    {'id': 'pagedown', 'defaultLabel': 'Botão 4', 'sub': 'PageDown', 'color': Colors.tealAccent},
    {'id': 'home', 'defaultLabel': 'Botão 5', 'sub': 'Home', 'color': Colors.amberAccent},
    {'id': 'end', 'defaultLabel': 'Botão 6', 'sub': 'End', 'color': Colors.orangeAccent},
    {'id': 'numpad_div', 'defaultLabel': 'Botão 7', 'sub': 'Num /', 'color': Colors.deepOrangeAccent},
    {'id': 'numpad_mul', 'defaultLabel': 'Botão 8', 'sub': 'Num *', 'color': Colors.redAccent},
    {'id': 'numpad_sub', 'defaultLabel': 'Botão 9', 'sub': 'Num -', 'color': Colors.purpleAccent},
    {'id': 'numpad_dot', 'defaultLabel': 'Botão 10', 'sub': 'Num .', 'color': Colors.deepPurpleAccent},
    {'id': 'scroll_lock', 'defaultLabel': 'Botão 11', 'sub': 'ScrollLock', 'color': Colors.indigoAccent},
    {'id': 'pause', 'defaultLabel': 'Botão 12', 'sub': 'Pause', 'color': Colors.pinkAccent},
  ];

  List<Map<String, dynamic>> get _currentButtons {
    switch (_currentMode) {
      case DeckMode.fKeys:
        return _fKeysButtons;
      case DeckMode.numpad:
        return _numpadButtons;
      case DeckMode.nav:
        return _navButtons;
    }
  }

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
      final modeStr = prefs.getString('deckMode') ?? 'fKeys';
      if (modeStr == 'numpad') {
        _currentMode = DeckMode.numpad;
      } else if (modeStr == 'nav') {
        _currentMode = DeckMode.nav;
      } else {
        _currentMode = DeckMode.fKeys;
      }

      for (final btn in [..._fKeysButtons, ..._numpadButtons, ..._navButtons]) {
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

  Future<void> _setDeckMode(DeckMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeStr;
    switch (mode) {
      case DeckMode.fKeys:
        modeStr = 'fKeys';
        break;
      case DeckMode.numpad:
        modeStr = 'numpad';
        break;
      case DeckMode.nav:
        modeStr = 'nav';
        break;
    }
    await prefs.setString('deckMode', modeStr);
    setState(() {
      _currentMode = mode;
      _pressedKeys.clear();
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
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              // Linha com Host IP e dica de renomeação (com Expanded para evitar overflow em telas estreitas)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Host PC: $_serverIp:$_serverPort',
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Segure para renomear ✏️',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Alternador de Perfis/Modos de Teclas (3 modos responsivos)
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<DeckMode>(
                  segments: const [
                    ButtonSegment<DeckMode>(
                      value: DeckMode.fKeys,
                      icon: Icon(Icons.live_tv_rounded, size: 14),
                      label: Text('Streamlabs (F13–F24)', style: TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                    ),
                    ButtonSegment<DeckMode>(
                      value: DeckMode.numpad,
                      icon: Icon(Icons.pin_rounded, size: 14),
                      label: Text('Minecraft (Numpad)', style: TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                    ),
                    ButtonSegment<DeckMode>(
                      value: DeckMode.nav,
                      icon: Icon(Icons.navigation_rounded, size: 14),
                      label: Text('Mods (Navegação)', style: TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  selected: {_currentMode},
                  onSelectionChanged: (Set<DeckMode> newSelection) {
                    _setDeckMode(newSelection.first);
                  },
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Banner informativo do modo ativo e prevenção de conflitos
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _currentMode == DeckMode.fKeys
                      ? Colors.blueAccent.withValues(alpha: 0.12)
                      : (_currentMode == DeckMode.numpad
                          ? Colors.amberAccent.withValues(alpha: 0.12)
                          : Colors.purpleAccent.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentMode == DeckMode.fKeys
                        ? Colors.blueAccent.withValues(alpha: 0.3)
                        : (_currentMode == DeckMode.numpad
                            ? Colors.amberAccent.withValues(alpha: 0.3)
                            : Colors.purpleAccent.withValues(alpha: 0.3)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentMode == DeckMode.fKeys
                          ? Icons.info_outline
                          : (_currentMode == DeckMode.numpad
                              ? Icons.warning_amber_rounded
                              : Icons.extension_rounded),
                      size: 16,
                      color: _currentMode == DeckMode.fKeys
                          ? Colors.lightBlueAccent
                          : (_currentMode == DeckMode.numpad
                              ? Colors.amberAccent
                              : Colors.purpleAccent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentMode == DeckMode.fKeys
                            ? 'Ideal para Streamlabs em 2º plano: atalhos de live sem conflito com o jogo.'
                            : (_currentMode == DeckMode.numpad
                                ? 'DirectInput ativo para Minecraft: atenção se já usa teclas do Numpad físico para mods.'
                                : 'Teclas de navegação (Insert, PageUp...) para gerenciar mods de administrador no Minecraft.'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _currentMode == DeckMode.fKeys
                              ? Colors.white70
                              : (_currentMode == DeckMode.numpad
                                  ? Colors.amber.shade200
                                  : Colors.purple.shade100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Grade dos 12 botões interativos
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 colunas para acomodar 12 botões confortavelmente
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: _currentButtons.length,
                  itemBuilder: (context, index) {
                    final btn = _currentButtons[index];
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
      onLongPress: () {
        _handleKey(id, 'up'); // Libera tecla imediatamente para não ativar comandos ao renomear
        _showRenameDialog(id, label, defaultLabel);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        decoration: BoxDecoration(
          color: isPressed ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPressed ? Colors.white : color.withValues(alpha: 0.7),
            width: isPressed ? 2.5 : 1.5,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPressed ? Colors.white : color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
