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

  testWidgets('Renomear botao via toque longo (long press)', (WidgetTester tester) async {
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

  testWidgets('Carregamento de preferencias salvas do SharedPreferences', (WidgetTester tester) async {
    configureViewport(tester);
    SharedPreferences.setMockInitialValues({
      'deckMode': 'sixPack',
      'label_insert': 'Ação Customizada',
    });

    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Deve iniciar no modo Six Pack com o nome personalizado
    expect(find.text('Ação Customizada'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
