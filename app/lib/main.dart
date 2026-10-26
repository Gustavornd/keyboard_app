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

/// Modelo para armazenar perfis e layouts customizados
class DeckProfile {
  final String id;
  String name;
  final List<String> buttonKeys;
  final Map<String, String> customLabels;

  DeckProfile({
    required this.id,
    required this.name,
    required this.buttonKeys,
    Map<String, String>? customLabels,
  }) : customLabels = customLabels ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'buttonKeys': buttonKeys,
    'customLabels': customLabels,
  };

  factory DeckProfile.fromJson(Map<String, dynamic> json) {
    return DeckProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      buttonKeys: List<String>.from(json['buttonKeys'] as List? ?? []),
      customLabels: Map<String, String>.from(json['customLabels'] as Map? ?? {}),
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
  DeckMode _currentMode = DeckMode.generic;

  // Gerenciamento de Perfis / Custom Views
  final List<DeckProfile> _profiles = [];
  String? _activeProfileId; // null indica a "Tela Principal" com as 3 abas

  DeckProfile? get _activeProfile {
    if (_activeProfileId == null) return null;
    for (final p in _profiles) {
      if (p.id == _activeProfileId) return p;
    }
    return null;
  }

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

  // Aba 3: Six Pack - Bloco clássico de 6 teclas + Controles de Mídia
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

  // Catálogo completo indexado por ID
  static final Map<String, Map<String, dynamic>> _catalog = {
    for (final btn in [..._genericButtons, ..._numpadButtons, ..._sixPackButtons])
      btn['id'] as String: btn,
  };

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

      // Carregar perfis personalizados
      _profiles.clear();
      final profilesJson = prefs.getString('custom_profiles_v1');
      if (profilesJson != null && profilesJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(profilesJson);
          for (final item in decoded) {
            _profiles.add(DeckProfile.fromJson(item as Map<String, dynamic>));
          }
        } catch (e) {
          debugPrint('Erro ao decodificar perfis: $e');
        }
      }

      final savedActiveId = prefs.getString('active_profile_id');
      if (savedActiveId != null && _profiles.any((p) => p.id == savedActiveId)) {
        _activeProfileId = savedActiveId;
      } else {
        _activeProfileId = null;
      }

      // Carregar labels globais da tela principal
      for (final btn in [..._genericButtons, ..._numpadButtons, ..._sixPackButtons]) {
        final id = btn['id'] as String;
        final saved = prefs.getString('label_$id');
        if (saved != null && saved.isNotEmpty) {
          _customLabels[id] = saved;
        }
      }
    });
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    await prefs.setString('custom_profiles_v1', encoded);
    if (_activeProfileId != null) {
      await prefs.setString('active_profile_id', _activeProfileId!);
    } else {
      await prefs.remove('active_profile_id');
    }
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

  // Dialog de renomeação na Tela Principal
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

  // Dialog para criar novo perfil
  void _showCreateProfileDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CRIAR NOVA VIEW'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da View',
                  hintText: 'ex: Live Stream, Simulador',
                  border: OutlineInputBorder(),
                ),
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
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newProfile = DeckProfile(
                    id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    buttonKeys: [],
                  );
                  setState(() {
                    _profiles.add(newProfile);
                    _activeProfileId = newProfile.id;
                    _pressedKeys.clear();
                  });
                  _saveProfiles();
                  Navigator.pop(context);
                }
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  // Dialog para renomear perfil
  void _showRenameProfileDialog(DeckProfile profile) {
    final controller = TextEditingController(text: profile.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('RENOMEAR VIEW'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome da View',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    profile.name = name;
                  });
                  _saveProfiles();
                }
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // Dialog de confirmação para excluir perfil
  void _showDeleteProfileConfirmation(DeckProfile profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('EXCLUIR VIEW'),
          content: Text('Tem certeza de que deseja excluir a view "${profile.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _profiles.removeWhere((p) => p.id == profile.id);
                  if (_activeProfileId == profile.id) {
                    _activeProfileId = null;
                  }
                  _pressedKeys.clear();
                });
                _saveProfiles();
                Navigator.pop(context);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  // Modal para adicionar teclas à view customizada
  void _showAddButtonsSheet() {
    final profile = _activeProfile;
    if (profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = [
              {'title': 'Generic (F13 a F24)', 'list': _genericButtons},
              {'title': 'Numpad (Teclado Numérico)', 'list': _numpadButtons},
              {'title': 'Six Pack (Navegação)', 'list': _sixPackButtons.sublist(0, 6)},
              {'title': 'Controles de Mídia', 'list': _sixPackButtons.sublist(6)},
            ];

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adicionar Teclas (${profile.name})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Toque nas teclas para incluir nesta view',
                                style: TextStyle(fontSize: 12, color: Colors.white60),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: categories.length,
                          itemBuilder: (context, catIdx) {
                            final cat = categories[catIdx];
                            final title = cat['title'] as String;
                            final list = cat['list'] as List<Map<String, dynamic>>;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white54,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: list.map((btn) {
                                    final id = btn['id'] as String;
                                    final defaultLabel = btn['defaultLabel'] as String;
                                    final icon = btn['icon'] as IconData?;
                                    final color = btn['color'] as Color;
                                    final isAdded = profile.buttonKeys.contains(id);

                                    return ActionChip(
                                      avatar: isAdded
                                          ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18)
                                          : (icon != null
                                              ? Icon(icon, color: color, size: 16)
                                              : null),
                                      label: Text(defaultLabel),
                                      backgroundColor: isAdded
                                          ? Colors.greenAccent.withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.05),
                                      side: BorderSide(
                                        color: isAdded
                                            ? Colors.greenAccent.withValues(alpha: 0.5)
                                            : Colors.white24,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          if (isAdded) {
                                            profile.buttonKeys.remove(id);
                                            profile.customLabels.remove(id);
                                          } else {
                                            profile.buttonKeys.add(id);
                                          }
                                        });
                                        setModalState(() {});
                                        _saveProfiles();
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Opções de botão na view customizada (Renomear nesta view ou Remover)
  void _showCustomViewButtonOptions(String keyId, String currentLabel, String defaultLabel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Opções da Tecla ($keyId)'.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Personalizar Nome nesta View'),
                subtitle: Text('Nome atual: $currentLabel'),
                onTap: () {
                  Navigator.pop(context);
                  _showContextualRenameDialog(keyId, currentLabel, defaultLabel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remover desta View', style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('Remove o botão desta tela sem afetar o servidor'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _activeProfile?.buttonKeys.remove(keyId);
                    _activeProfile?.customLabels.remove(keyId);
                  });
                  _saveProfiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Dialog de renomeação contextual no perfil ativo
  void _showContextualRenameDialog(String keyId, String currentLabel, String defaultLabel) {
    final controller = TextEditingController(text: currentLabel == defaultLabel ? '' : currentLabel);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nome no Perfil ($keyId)'.toUpperCase()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nome do Botão para este Perfil',
                  hintText: defaultLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deixe em branco para restaurar o nome padrão nesta view.',
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
                final text = controller.text.trim();
                setState(() {
                  if (text.isEmpty) {
                    _activeProfile?.customLabels.remove(keyId);
                  } else {
                    _activeProfile?.customLabels[keyId] = text;
                  }
                });
                _saveProfiles();
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

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard_customize_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stream Deck',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Perfis & Views Personalizadas',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.grid_view_rounded,
                color: _activeProfileId == null ? Theme.of(context).colorScheme.primary : Colors.white70,
              ),
              title: const Text('Tela Principal', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Generic, Numpad, Six Pack', style: TextStyle(fontSize: 11)),
              selected: _activeProfileId == null,
              selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() {
                  _activeProfileId = null;
                  _pressedKeys.clear();
                });
                _saveProfiles();
                Navigator.pop(context);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'VIEWS PERSONALIZADAS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${_profiles.length}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _profiles.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Nenhuma view personalizada criada ainda.\nToque em "+ Criar Nova View" abaixo para criar uma.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        final isSelected = _activeProfileId == profile.id;
                        return ListTile(
                          leading: Icon(
                            Icons.folder_special_rounded,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white60,
                          ),
                          title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('${profile.buttonKeys.length} botões', style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) {
                              if (val == 'rename') {
                                _showRenameProfileDialog(profile);
                              } else if (val == 'delete') {
                                _showDeleteProfileConfirmation(profile);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Renomear View'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 8),
                                    Text('Excluir View', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _activeProfileId = profile.id;
                              _pressedKeys.clear();
                            });
                            _saveProfiles();
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar Nova View'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreateProfileDialog();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProf = _activeProfile;
    final isCustomView = activeProf != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCustomView ? activeProf.name : 'Stream Deck Extra Keys',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isCustomView)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _showAddButtonsSheet,
              tooltip: 'Adicionar Teclas',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigModal,
            tooltip: 'Configurar IP do Computador',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              // Linha com Host IP e dica de renomeação
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
                      'Segure para opções ✏️',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Conteúdo da Tela: Principal vs Custom View
              if (!isCustomView) ...[
                // Alternador de Perfis/Modos de Teclas da Tela Principal
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
                // Banner informativo do modo ativo
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
                // Grade de botões da Tela Principal
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
                        onLongPress: () => _showRenameDialog(id, displayLabel, defaultLabel),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Banner informativo da Custom View
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_special_rounded, size: 16, color: Colors.deepPurpleAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'View: ${activeProf.name} • ${activeProf.buttonKeys.length} botões adicionados',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                      InkWell(
                        onTap: _showAddButtonsSheet,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.add, size: 14, color: Colors.deepPurpleAccent),
                              SizedBox(width: 2),
                              Text('Adicionar', style: TextStyle(fontSize: 11, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Grade da Custom View ou Estado Vazio
                Expanded(
                  child: activeProf.buttonKeys.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.touch_app_rounded, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhum botão nesta view',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Monte seu layout personalizado mesclando teclas\nde F13 a F24, Numpad, Navegação e Mídia.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.white38),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Adicionar Teclas (+)'),
                                onPressed: _showAddButtonsSheet,
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: activeProf.buttonKeys.length,
                          itemBuilder: (context, index) {
                            final keyId = activeProf.buttonKeys[index];
                            final btnDef = _catalog[keyId] ?? {
                              'id': keyId,
                              'defaultLabel': keyId,
                              'sub': 'Custom',
                              'color': Colors.blueGrey,
                            };
                            final defaultLabel = btnDef['defaultLabel'] as String;
                            // Alias contextual do perfil prevalece; se não houver, usa label global ou padrão
                            final displayLabel = activeProf.customLabels[keyId] ?? _customLabels[keyId] ?? defaultLabel;
                            final sub = btnDef['sub'] as String;
                            final color = btnDef['color'] as Color;
                            final icon = btnDef['icon'] as IconData?;
                            final isPressed = _pressedKeys.contains(keyId);

                            return _buildExtraKeyButton(
                              id: keyId,
                              label: displayLabel,
                              defaultLabel: defaultLabel,
                              sub: sub,
                              color: color,
                              icon: icon,
                              isPressed: isPressed,
                              onLongPress: () => _showCustomViewButtonOptions(keyId, displayLabel, defaultLabel),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Construtor de botão Stream Deck
  /// CRÍTICO: Utiliza estritamente GestureDetector (onTapDown e onTapUp/onTapCancel)
  /// para suportar pressão contínua e real-time UDP. NUNCA utilizar ElevatedButton/onPressed.
  Widget _buildExtraKeyButton({
    required String id,
    required String label,
    required String defaultLabel,
    required String sub,
    required Color color,
    required bool isPressed,
    IconData? icon,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTapDown: (_) => _handleKey(id, 'down'),
      onTapUp: (_) => _handleKey(id, 'up'),
      onTapCancel: () => _handleKey(id, 'up'),
      onLongPress: () {
        _handleKey(id, 'up'); // Libera tecla imediatamente para não ativar comandos ao abrir opções
        if (onLongPress != null) {
          onLongPress();
        } else {
          _showRenameDialog(id, label, defaultLabel);
        }
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
