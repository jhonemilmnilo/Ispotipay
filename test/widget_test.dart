import 'package:flutter_test/flutter_test.dart';
import 'package:ispotipay/main.dart';

void main() {
  testWidgets('IspotipayApp builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const IspotipayApp());
    expect(find.text('ispoti'), findsOneWidget);
    expect(find.text('pay'), findsOneWidget);
  });
}
