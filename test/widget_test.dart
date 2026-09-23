// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pick_location/main.dart';
import 'package:pick_location/services/navigation.dart';

void main() {
  test('App defaults to the map title in Arabic', () {
    expect(const AppStrings(AppLanguage.ar).mapTitle, 'اختيار الموقع');
    expect(const AppStrings(AppLanguage.ar).navMap, 'الخريطة');
  });

  testWidgets('Review page allows copying coordinates to clipboard', (WidgetTester tester) async {
    final clipboardWrites = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          clipboardWrites.add(args['text'] as String);
          return null;
        }

        if (call.method == 'Clipboard.getData') {
          final text = clipboardWrites.isNotEmpty ? clipboardWrites.last : '24.713600, 46.675300';
          return <String, dynamic>{'text': text};
        }

        return null;
      },
    );

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewSubmitPage(
          strings: const AppStrings(AppLanguage.ar),
          currentLocation: const LatLng(24.7136, 46.6753),
          selectedLocation: const LatLng(24.7137, 46.6754),
          images: const [],
          details: 'تفاصيل اختبار',
          onToggleLanguage: () {},
          onToggleTheme: () {},
          onReportSent: () {},
          onGoToCurrentLocation: () {},
        ),
      ),
    );

    final match = find.textContaining('24.713600, 46.675300');
    expect(match, findsOneWidget);

    await tester.tap(match);
    await tester.pump();

    expect(clipboardWrites, isNotEmpty);
    expect(clipboardWrites.last, contains('24.713600, 46.675300'));
  });

  testWidgets('Review page shows only the PDF download action', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewSubmitPage(
          strings: const AppStrings(AppLanguage.ar),
          currentLocation: const LatLng(24.7136, 46.6753),
          selectedLocation: const LatLng(24.7137, 46.6754),
          images: const [],
          details: 'تفاصيل اختبار',
          onToggleLanguage: () {},
          onToggleTheme: () {},
          onReportSent: () {},
          onGoToCurrentLocation: () {},
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('تنزيل PDF'), findsOneWidget);
    expect(find.textContaining('طباعة'), findsNothing);
    expect(find.textContaining('Print'), findsNothing);
  });

  testWidgets('Review page theme toggle button invokes callback', (WidgetTester tester) async {
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewSubmitPage(
          strings: const AppStrings(AppLanguage.ar),
          currentLocation: const LatLng(24.7136, 46.6753),
          selectedLocation: const LatLng(24.7137, 46.6754),
          images: const [],
          details: 'تفاصيل اختبار',
          onToggleLanguage: () {},
          onToggleTheme: () {
            toggleCount++;
          },
          onReportSent: () {},
          onGoToCurrentLocation: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('الوضع'));
    await tester.pump();

    expect(toggleCount, 1);
  });

  testWidgets('Current location button toggles follow mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapPickerPage(
          strings: const AppStrings(AppLanguage.ar),
          currentLocation: const LatLng(24.7136, 46.6753),
          selectedLocation: const LatLng(24.7146, 46.6763),
          mapStyle: AppMapStyle.street,
          onMapStyleChanged: (_) {},
          onToggleLanguage: () {},
          onToggleTheme: () {},
          onCurrentLocationChanged: (_) {},
          onSelectedLocationChanged: (_) {},
          focusRequestVersion: 0,
        ),
      ),
    );

    expect(find.byTooltip('تتبع الموقع الحالي'), findsNWidgets(2));

    await tester.tap(find.byTooltip('تتبع الموقع الحالي').first);
    await tester.pump();

    expect(find.byTooltip('إيقاف متابعة الموقع الحالي'), findsNWidgets(2));
  });

  test('Direct navigation heading points from current location toward the selected point', () {
    const from = LatLng(24.7136, 46.6753);
    const to = LatLng(24.7146, 46.6763);

    final bearing = NavigationService.calculateBearingBetweenPoints(from, to);

    expect(bearing, inInclusiveRange(0, 360));
    expect(bearing, greaterThan(0));
  });

  test('Navigation service parses a route geometry into road-following points', () {
    final points = NavigationService.parseRouteGeometry({
      'routes': [
        {
          'geometry': {
            'coordinates': [
              [46.6753, 24.7136],
              [46.6758, 24.7140],
              [46.6763, 24.7146],
            ],
          },
        },
      ],
    });

    expect(points.length, 3);
    expect(points.first.latitude, closeTo(24.7136, 0.000001));
    expect(points.last.longitude, closeTo(46.6763, 0.000001));
  });

  test('Printing is supported on current Flutter target platform', () {
    expect(isPrintingSupportedOnCurrentPlatform(), isTrue);
  });
}
