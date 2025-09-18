// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/main.dart';

void main() {
  testWidgets('Kode Radar app loads and shows main content', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('Kode Radar Home Page'), findsOneWidget);
    
    // Verify that the settings icon is present
    expect(find.byIcon(Icons.settings), findsOneWidget);
    
    // Verify that the add button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Settings page can be opened', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Tap the settings icon
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify that we navigated to the settings page
    expect(find.text('Settings'), findsOneWidget);
    
    // Verify that token sections are present
    expect(find.text('GitHub Access Token'), findsOneWidget);
    expect(find.text('Azure DevOps Access Token'), findsOneWidget);
    
    // Verify that create token buttons are present
    expect(find.text('Create New Token'), findsNWidgets(2));
  });
}
