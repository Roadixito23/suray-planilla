import 'package:flutter_test/flutter_test.dart';
import 'package:suray_planilla/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SurayPlanillaApp());
    expect(find.text('Suray Planilla'), findsWidgets);
  });
}
