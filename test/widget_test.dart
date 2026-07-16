// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Kode Radar app loads and shows main content', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('Kode Radar Home Page'), findsOneWidget);

    // Primary actions are shown as icons.
    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.byIcon(Icons.dynamic_feed), findsOneWidget);
    expect(find.byIcon(Icons.radar), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    // Secondary actions live in the overflow menu.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    // Verify that the add button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Teams page can be opened from the overflow menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teams'));
    await tester.pumpAndSettle();

    // Navigated to the Teams page; empty state since no teams are configured.
    expect(find.widgetWithText(AppBar, 'Teams'), findsOneWidget);
    expect(find.text('No teams yet.'), findsOneWidget);
  });

  testWidgets('Attention inbox can be opened', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap the attention inbox icon
    await tester.tap(find.byIcon(Icons.inbox));
    await tester.pumpAndSettle();

    // Verify that we navigated to the Attention inbox page and it renders its
    // empty state (no repositories are configured in the test environment).
    expect(find.widgetWithText(AppBar, 'Attention'), findsOneWidget);
    expect(
      find.text('Nothing needs your attention right now.'),
      findsOneWidget,
    );
  });

  testWidgets('Manage Tokens page can be opened from the overflow menu', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Open the overflow menu, then the manage tokens item.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage tokens'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the manage tokens page
    expect(find.text('Manage Tokens'), findsOneWidget);
    expect(find.text('No tokens added yet.'), findsOneWidget);
  });
}
