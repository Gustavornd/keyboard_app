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

  testWidgets('StreamDeckApp smoke test - modo padrao F13-F24', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    expect(find.text('Stream Deck Extra Keys'), findsOneWidget);
    expect(find.text('Streamlabs (F13–F24)'), findsOneWidget);
    expect(find.text('Minecraft (Numpad)'), findsOneWidget);
    expect(find.text('Mods (Navegação)'), findsOneWidget);
    expect(find.text('Botão 1'), findsOneWidget);
    expect(find.text('F13'), findsOneWidget);
    expect(find.text('F24'), findsOneWidget);
  });

  testWidgets('Alternancia para Modo Numpad (Minecraft)', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Toca no segmento Minecraft (Numpad)
    final numpadSegment = find.text('Minecraft (Numpad)');
    expect(numpadSegment, findsOneWidget);
    await tester.tap(numpadSegment);
    await tester.pumpAndSettle();

    // Agora deve exibir teclas numpad
    expect(find.text('Num 1'), findsOneWidget);
    expect(find.text('Num 2'), findsOneWidget);
    expect(find.text('Num +'), findsOneWidget);
    expect(find.text('Num Enter'), findsOneWidget);
    expect(find.textContaining('DirectInput ativo para Minecraft'), findsOneWidget);
  });

  testWidgets('Alternancia para Modo Navegacao (Mods)', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Toca no segmento Mods (Navegação)
    final navSegment = find.text('Mods (Navegação)');
    expect(navSegment, findsOneWidget);
    await tester.tap(navSegment);
    await tester.pumpAndSettle();

    // Deve exibir teclas de navegação
    expect(find.text('Insert'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('PageUp'), findsOneWidget);
    expect(find.text('PageDown'), findsOneWidget);
    expect(find.text('ScrollLock'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.textContaining('Teclas de navegação (Insert, PageUp...)'), findsOneWidget);
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
      await tester.tap(find.text('Minecraft (Numpad)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Mods (Navegação)'));
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
      'deckMode': 'nav',
      'label_insert': 'Mod Menu Admin',
    });

    await tester.pumpWidget(const StreamDeckApp());
    await tester.pumpAndSettle();

    // Deve iniciar no modo Navegação com o nome personalizado
    expect(find.text('Mod Menu Admin'), findsOneWidget);
    expect(find.text('Insert'), findsOneWidget);
  });
}
