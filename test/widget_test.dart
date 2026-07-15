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

    // Verify that the manage tokens and manage repositories actions are present
    expect(find.byIcon(Icons.vpn_key), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);

    // Verify that the attention inbox action is present
    expect(find.byIcon(Icons.inbox), findsOneWidget);

    // Verify that the Teams action is present
    expect(find.byIcon(Icons.groups), findsOneWidget);

    // Verify that the add button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Teams page can be opened', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.groups));
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

  testWidgets('Manage Tokens page can be opened', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Tap the manage tokens icon
    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();

    // Verify that we navigated to the manage tokens page
    expect(find.text('Manage Tokens'), findsOneWidget);
    expect(find.text('No tokens added yet.'), findsOneWidget);
  });
}
