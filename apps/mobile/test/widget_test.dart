import 'package:flutter_test/flutter_test.dart';

import 'package:kazi_mobile/main.dart';

void main() {
  testWidgets('KAZI shell renders main navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const KaziApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Browse all services'), findsOneWidget);
  });
}
