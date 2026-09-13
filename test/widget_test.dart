import 'package:flutter_test/flutter_test.dart';
import 'package:caferio/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CaferioApp());
    expect(find.text('Welcome to Caferio'), findsOneWidget);
  });
}
