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
  generic, // F13 a F24 (Teclas de função estendidas independentes)
  numpad,  // Numpad Completo (0 a 9 e operadores matemáticos)
  sixPack, // Six Pack (Insert, Home, PageUp, Delete, End, PageDown + Controles de Mídia)
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
  DeckMode _currentMode = DeckMode.generic;

  // Aba 1: Generic - Exclusivamente teclas de função F13 até F24
  static const List<Map<String, dynamic>> _genericButtons = [
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

  // Aba 2: Numpad - Agrupa TODOS os botões referentes ao teclado numérico
  static const List<Map<String, dynamic>> _numpadButtons = [
    {'id': 'numpad_7', 'defaultLabel': 'Num 7', 'sub': 'Numpad', 'color': Colors.blueAccent},
    {'id': 'numpad_8', 'defaultLabel': 'Num 8', 'sub': 'Numpad', 'color': Colors.blueAccent},
    {'id': 'numpad_9', 'defaultLabel': 'Num 9', 'sub': 'Numpad', 'color': Colors.blueAccent},
    {'id': 'numpad_div', 'defaultLabel': 'Num /', 'sub': 'Numpad', 'color': Colors.cyanAccent},

    {'id': 'numpad_4', 'defaultLabel': 'Num 4', 'sub': 'Numpad', 'color': Colors.tealAccent},
    {'id': 'numpad_5', 'defaultLabel': 'Num 5', 'sub': 'Numpad', 'color': Colors.tealAccent},
    {'id': 'numpad_6', 'defaultLabel': 'Num 6', 'sub': 'Numpad', 'color': Colors.tealAccent},
    {'id': 'numpad_mul', 'defaultLabel': 'Num *', 'sub': 'Numpad', 'color': Colors.cyanAccent},

    {'id': 'numpad_1', 'defaultLabel': 'Num 1', 'sub': 'Numpad', 'color': Colors.greenAccent},
    {'id': 'numpad_2', 'defaultLabel': 'Num 2', 'sub': 'Numpad', 'color': Colors.greenAccent},
    {'id': 'numpad_3', 'defaultLabel': 'Num 3', 'sub': 'Numpad', 'color': Colors.greenAccent},
    {'id': 'numpad_sub', 'defaultLabel': 'Num -', 'sub': 'Numpad', 'color': Colors.amberAccent},

    {'id': 'numpad_0', 'defaultLabel': 'Num 0', 'sub': 'Numpad', 'color': Colors.orangeAccent},
    {'id': 'numpad_dot', 'defaultLabel': 'Num .', 'sub': 'Numpad', 'color': Colors.orangeAccent},
    {'id': 'numpad_enter', 'defaultLabel': 'Num Enter', 'sub': 'Numpad', 'color': Colors.redAccent},
    {'id': 'numpad_add', 'defaultLabel': 'Num +', 'sub': 'Numpad', 'color': Colors.amberAccent},
  ];

  // Aba 3: Six Pack - Bloco clássico de 6 teclas (Insert, Home, PageUp, Delete, End, PageDown) + Controles de Mídia
  static const List<Map<String, dynamic>> _sixPackButtons = [
    // Bloco Clássico de Navegação (Six Pack)
    {'id': 'insert', 'defaultLabel': 'Insert', 'sub': 'Nav', 'color': Colors.blueAccent},
    {'id': 'home', 'defaultLabel': 'Home', 'sub': 'Nav', 'color': Colors.cyanAccent},
    {'id': 'pageup', 'defaultLabel': 'Page Up', 'sub': 'Nav', 'color': Colors.greenAccent},
    {'id': 'delete', 'defaultLabel': 'Delete', 'sub': 'Nav', 'color': Colors.tealAccent},
    {'id': 'end', 'defaultLabel': 'End', 'sub': 'Nav', 'color': Colors.amberAccent},
    {'id': 'pagedown', 'defaultLabel': 'Page Down', 'sub': 'Nav', 'color': Colors.orangeAccent},

    // Controles de Mídia do Sistema
    {'id': 'media_prev', 'defaultLabel': 'Previous', 'sub': 'Media', 'color': Colors.purpleAccent, 'icon': Icons.skip_previous_rounded},
    {'id': 'media_play_pause', 'defaultLabel': 'Play / Pause', 'sub': 'Media', 'color': Colors.deepPurpleAccent, 'icon': Icons.play_arrow_rounded},
    {'id': 'media_next', 'defaultLabel': 'Next', 'sub': 'Media', 'color': Colors.indigoAccent, 'icon': Icons.skip_next_rounded},
    {'id': 'volume_down', 'defaultLabel': 'Vol -', 'sub': 'Media', 'color': Colors.deepOrangeAccent, 'icon': Icons.volume_down_rounded},
    {'id': 'volume_mute', 'defaultLabel': 'Mute', 'sub': 'Media', 'color': Colors.redAccent, 'icon': Icons.volume_off_rounded},
    {'id': 'volume_up', 'defaultLabel': 'Vol +', 'sub': 'Media', 'color': Colors.pinkAccent, 'icon': Icons.volume_up_rounded},
  ];

  List<Map<String, dynamic>> get _currentButtons {
    switch (_currentMode) {
      case DeckMode.generic:
        return _genericButtons;
      case DeckMode.numpad:
        return _numpadButtons;
      case DeckMode.sixPack:
        return _sixPackButtons;
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
      final modeStr = prefs.getString('deckMode') ?? 'generic';
      if (modeStr == 'numpad') {
        _currentMode = DeckMode.numpad;
      } else if (modeStr == 'sixPack' || modeStr == 'nav') {
        _currentMode = DeckMode.sixPack;
      } else {
        _currentMode = DeckMode.generic;
      }

      for (final btn in [..._genericButtons, ..._numpadButtons, ..._sixPackButtons]) {
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
      case DeckMode.generic:
        modeStr = 'generic';
        break;
      case DeckMode.numpad:
        modeStr = 'numpad';
        break;
      case DeckMode.sixPack:
        modeStr = 'sixPack';
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
              // Alternador de Perfis/Modos de Teclas (3 modos responsivos e agnósticos)
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<DeckMode>(
                  segments: const [
                    ButtonSegment<DeckMode>(
                      value: DeckMode.generic,
                      icon: Icon(Icons.grid_view_rounded, size: 14),
                      label: Text('Generic', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    ),
                    ButtonSegment<DeckMode>(
                      value: DeckMode.numpad,
                      icon: Icon(Icons.dialpad_rounded, size: 14),
                      label: Text('Numpad', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    ),
                    ButtonSegment<DeckMode>(
                      value: DeckMode.sixPack,
                      icon: Icon(Icons.apps_rounded, size: 14),
                      label: Text('Six Pack', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
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
              // Banner informativo do modo ativo (genérico e focado nas teclas)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _currentMode == DeckMode.generic
                      ? Colors.blueAccent.withValues(alpha: 0.12)
                      : (_currentMode == DeckMode.numpad
                          ? Colors.amberAccent.withValues(alpha: 0.12)
                          : Colors.purpleAccent.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentMode == DeckMode.generic
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
                      _currentMode == DeckMode.generic
                          ? Icons.info_outline
                          : (_currentMode == DeckMode.numpad
                              ? Icons.dialpad_rounded
                              : Icons.navigation_rounded),
                      size: 16,
                      color: _currentMode == DeckMode.generic
                          ? Colors.lightBlueAccent
                          : (_currentMode == DeckMode.numpad
                              ? Colors.amberAccent
                              : Colors.purpleAccent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentMode == DeckMode.generic
                            ? 'Teclas de função estendidas (F13 a F24) independentes do teclado físico.'
                            : (_currentMode == DeckMode.numpad
                                ? 'Teclado numérico completo (0 a 9 e operadores matemáticos).'
                                : 'Bloco de navegação (Insert, Delete, PageUp...) e controles de mídia do sistema.'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _currentMode == DeckMode.generic
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
              // Grade de botões interativos
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _currentMode == DeckMode.numpad ? 4 : 3,
                    crossAxisSpacing: _currentMode == DeckMode.numpad ? 8 : 10,
                    mainAxisSpacing: _currentMode == DeckMode.numpad ? 8 : 10,
                    childAspectRatio: _currentMode == DeckMode.numpad ? 0.95 : 1.0,
                  ),
                  itemCount: _currentButtons.length,
                  itemBuilder: (context, index) {
                    final btn = _currentButtons[index];
                    final id = btn['id'] as String;
                    final defaultLabel = btn['defaultLabel'] as String;
                    final displayLabel = _customLabels[id] ?? defaultLabel;
                    final sub = btn['sub'] as String;
                    final color = btn['color'] as Color;
                    final icon = btn['icon'] as IconData?;
                    final isPressed = _pressedKeys.contains(id);

                    return _buildExtraKeyButton(
                      id: id,
                      label: displayLabel,
                      defaultLabel: defaultLabel,
                      sub: sub,
                      color: color,
                      icon: icon,
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
    IconData? icon,
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
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: isPressed ? Colors.white : color, size: 20),
                  const SizedBox(height: 2),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _currentMode == DeckMode.numpad ? 13 : 14,
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
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
