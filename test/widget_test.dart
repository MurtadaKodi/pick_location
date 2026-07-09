// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:pick_location/main.dart';

void main() {
  testWidgets('App shows map page by default', (WidgetTester tester) async {
    await tester.pumpWidget(const PickLocationApp());

    expect(find.text('اختيار الموقع'), findsOneWidget);
    expect(find.text('الخريطة'), findsOneWidget);
    expect(find.text('الصور والتفاصيل'), findsOneWidget);
    expect(find.text('المراجعة والإرسال'), findsOneWidget);
  });
}
