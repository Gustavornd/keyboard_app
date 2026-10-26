import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_deck_client/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('StreamDeckApp smoke test - modo padrao Generic (F13-F24)', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    expect(find.text('Stream Deck Extra Keys'), findsOneWidget);
    expect(find.text('Generic'), findsOneWidget);
    expect(find.text('Numpad'), findsOneWidget);
    expect(find.text('Six Pack'), findsOneWidget);
    expect(find.text('Botão 1'), findsOneWidget);
    expect(find.text('F13'), findsOneWidget);
    expect(find.text('F24'), findsOneWidget);
  });

  testWidgets('Alternancia para Modo Numpad com todas as 16 teclas', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Toca no segmento Numpad
    final numpadSegment = find.text('Numpad');
    expect(numpadSegment, findsOneWidget);
    await tester.tap(numpadSegment);
    await tester.pumpAndSettle();

    // Deve exibir todas as teclas do numpad e operadores
    expect(find.text('Num 7'), findsOneWidget);
    expect(find.text('Num 8'), findsOneWidget);
    expect(find.text('Num 9'), findsOneWidget);
    expect(find.text('Num /'), findsOneWidget);
    expect(find.text('Num 4'), findsOneWidget);
    expect(find.text('Num 5'), findsOneWidget);
    expect(find.text('Num 6'), findsOneWidget);
    expect(find.text('Num *'), findsOneWidget);
    expect(find.text('Num 1'), findsOneWidget);
    expect(find.text('Num 2'), findsOneWidget);
    expect(find.text('Num 3'), findsOneWidget);
    expect(find.text('Num -'), findsOneWidget);
    expect(find.text('Num 0'), findsOneWidget);
    expect(find.text('Num .'), findsOneWidget);
    expect(find.text('Num Enter'), findsOneWidget);
    expect(find.text('Num +'), findsOneWidget);
    expect(find.textContaining('Teclado numérico completo'), findsOneWidget);
  });

  testWidgets('Alternancia para Modo Six Pack com navegacao e controles de midia', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Toca no segmento Six Pack
    final sixPackSegment = find.text('Six Pack');
    expect(sixPackSegment, findsOneWidget);
    await tester.tap(sixPackSegment);
    await tester.pumpAndSettle();

    // Deve exibir teclas classicas de navegacao
    expect(find.text('Insert'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Page Up'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.text('Page Down'), findsOneWidget);

    // Deve exibir controles de midia do sistema
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Play / Pause'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Vol -'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Vol +'), findsOneWidget);
    expect(find.textContaining('Bloco de navegação'), findsOneWidget);
  });

  testWidgets('Responsividade em tela estreita de smartphone (360x640 e 320x480 sem overflow)', (WidgetTester tester) async {
    for (final size in [const Size(360, 640), const Size(320, 480)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StreamDeckApp());
      await tester.pumpAndSettle();

      // Nenhum erro de overflow deve ter sido lançado
      expect(tester.takeException(), isNull);

      // Alterna entre os modos para garantir responsividade em todos
      await tester.tap(find.text('Numpad'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Six Pack'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Renomear botao via toque longo na Tela Principal', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Long press no Botão 1
    final botao1 = find.text('Botão 1');
    expect(botao1, findsOneWidget);
    await tester.longPress(botao1);
    await tester.pumpAndSettle();

    // Dialog deve estar aberto
    expect(find.text('PERSONALIZAR NOME (F13)'), findsOneWidget);
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // Digita novo nome
    await tester.enterText(textField, 'Cena Live');
    await tester.pumpAndSettle();

    // Clica em Salvar
    final salvarBtn = find.text('Salvar');
    expect(salvarBtn, findsOneWidget);
    await tester.tap(salvarBtn);
    await tester.pumpAndSettle();

    // O botão agora exibe 'Cena Live'
    expect(find.text('Cena Live'), findsOneWidget);
  });

  testWidgets('Criar nova View Personalizada pelo Drawer lateral', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Abre o Drawer lateral pelo ícone de menu
    final drawerFinder = find.byTooltip('Open navigation menu');
    expect(drawerFinder, findsOneWidget);
    await tester.tap(drawerFinder);
    await tester.pumpAndSettle();

    // Deve exibir itens do Drawer
    expect(find.text('Stream Deck'), findsOneWidget);
    expect(find.text('Tela Principal'), findsOneWidget);
    expect(find.text('Criar Nova View'), findsOneWidget);

    // Toca em "Criar Nova View"
    await tester.tap(find.text('Criar Nova View'));
    await tester.pumpAndSettle();

    // Dialog aberto
    expect(find.text('CRIAR NOVA VIEW'), findsOneWidget);
    final nameField = find.byType(TextField);
    expect(nameField, findsOneWidget);

    // Digita nome "Live Stream" e clica em Criar
    await tester.enterText(nameField, 'Live Stream');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    // A AppBar agora exibe "Live Stream" e a view está vazia inicialmente
    expect(find.text('Live Stream'), findsOneWidget);
    expect(find.text('Nenhum botão nesta view'), findsOneWidget);
    expect(find.text('Adicionar Teclas (+)'), findsOneWidget);
  });

  testWidgets('Adicionar teclas multimodais na View Personalizada e testar eventos de toque', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Abre drawer e cria view "Simulador"
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar Nova View'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Simulador');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    // Clica em Adicionar Teclas (+)
    await tester.tap(find.text('Adicionar Teclas (+)'));
    await tester.pumpAndSettle();

    // Bottom sheet de adição aberto
    expect(find.text('Adicionar Teclas (Simulador)'), findsOneWidget);

    // Adiciona F13 (Botão 1) e Num 2
    final btn1Chip = find.widgetWithText(ActionChip, 'Botão 1');
    expect(btn1Chip, findsOneWidget);
    await tester.tap(btn1Chip);
    await tester.pumpAndSettle();

    final num2Chip = find.widgetWithText(ActionChip, 'Num 2');
    expect(num2Chip, findsOneWidget);
    await tester.tap(num2Chip);
    await tester.pumpAndSettle();

    // Fecha o modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Na view "Simulador", agora ambos os botões aparecem juntos na mesma tela!
    expect(find.text('Botão 1'), findsOneWidget);
    expect(find.text('Num 2'), findsOneWidget);

    // CRÍTICO: Testa preservação de eventos de toque contínuo (GestureDetector onTapDown / onTapUp)
    final gestureButton = find.text('Botão 1');
    final gesture = await tester.startGesture(tester.getCenter(gestureButton));
    await tester.pump(const Duration(milliseconds: 50));
    // Tecla pressionada com sucesso sem exceção
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renomeacao contextual (alias) exclusivo da View Personalizada', (WidgetTester tester) async {
    configureViewport(tester);

    // Inicializa com um perfil já salvo
    final initialProfiles = [
      {
        'id': 'profile_live',
        'name': 'Live Stream',
        'buttonKeys': ['f13', 'numpad_2'],
        'customLabels': <String, String>{},
      }
    ];

    SharedPreferences.setMockInitialValues({
      'custom_profiles_v1': jsonEncode(initialProfiles),
      'active_profile_id': 'profile_live',
    });

    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Estamos na view "Live Stream"
    expect(find.text('Live Stream'), findsOneWidget);
    expect(find.text('Botão 1'), findsOneWidget);

    // Segura "Botão 1" para abrir menu de contexto da view
    await tester.longPress(find.text('Botão 1'));
    await tester.pumpAndSettle();

    // Modal de opções da tecla na view
    expect(find.text('OPÇÕES DA TECLA (F13)'), findsOneWidget);
    expect(find.text('Personalizar Nome nesta View'), findsOneWidget);
    expect(find.text('Remover desta View'), findsOneWidget);

    // Toca em Personalizar Nome nesta View
    await tester.tap(find.text('Personalizar Nome nesta View'));
    await tester.pumpAndSettle();

    // Digita alias contextual
    expect(find.text('NOME NO PERFIL (F13)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Trocar Cena');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Na view atual, o botão agora se chama "Trocar Cena"
    expect(find.text('Trocar Cena'), findsOneWidget);

    // Abre Drawer e volta para a Tela Principal
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tela Principal'));
    await tester.pumpAndSettle();

    // Na Tela Principal, o botão F13 NÃO tem o nome "Trocar Cena", mantendo seu nome original!
    expect(find.text('Stream Deck Extra Keys'), findsOneWidget);
    expect(find.text('Botão 1'), findsOneWidget);
    expect(find.text('Trocar Cena'), findsNothing);
  });

  testWidgets('Excluir View Personalizada e retornar para a Tela Principal', (WidgetTester tester) async {
    configureViewport(tester);

    final initialProfiles = [
      {
        'id': 'profile_teste',
        'name': 'Perfil Teste',
        'buttonKeys': ['f13'],
        'customLabels': <String, String>{},
      }
    ];

    SharedPreferences.setMockInitialValues({
      'custom_profiles_v1': jsonEncode(initialProfiles),
      'active_profile_id': 'profile_teste',
    });

    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    expect(find.text('Perfil Teste'), findsOneWidget);

    // Abre Drawer
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Toca no menu do perfil (três pontos)
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Seleciona Excluir View
    await tester.tap(find.text('Excluir View'));
    await tester.pumpAndSettle();

    // Confirma exclusão no dialog
    expect(find.text('EXCLUIR VIEW'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    // Fecha o Drawer tocando na tela ou navegando
    // Ao excluir o perfil ativo, automaticamente retorna para a Tela Principal
    expect(find.text('Stream Deck Extra Keys'), findsOneWidget);
  });
}
