import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck_client/main.dart';

void main() {
  testWidgets('StreamDeckApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StreamDeckApp());
    expect(find.text('Stream Deck Extra Keys'), findsOneWidget);
    expect(find.text('Botão 1'), findsOneWidget);
    expect(find.text('F13'), findsOneWidget);
  });
}
