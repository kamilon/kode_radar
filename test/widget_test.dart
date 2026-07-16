// Widget tests for the home navigation shell.

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

  // Pin a narrow surface so the shell renders the bottom NavigationBar (a wide
  // surface would use the NavigationRail instead).
  void useNarrowSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // The surfaces show an infinite CircularProgressIndicator while loading and
  // the shell runs background timers, so pumpAndSettle can't be used. Pump in
  // bounded steps until the expected content appears instead.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 60,
  }) async {
    for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Opens the overflow menu and taps [label], fully completing the menu-open
  // and route-push animations so neither tap is swallowed mid-transition.
  Future<void> selectFromMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  final radarEmpty = find.text(
    'No repositories yet. Add some from Manage Repositories.',
  );

  testWidgets('opens on the Radar tab with bottom navigation', (tester) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(const MyApp());
    await pumpUntil(tester, radarEmpty);

    // Radar is the default landing surface.
    expect(find.widgetWithText(AppBar, 'Radar'), findsOneWidget);
    expect(radarEmpty, findsOneWidget);

    // The four primary surfaces are reachable via the bottom navigation bar.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget); // Attention
    expect(find.byIcon(Icons.radar), findsOneWidget); // Radar
    expect(find.byIcon(Icons.dynamic_feed), findsOneWidget); // Activity
    expect(find.byIcon(Icons.search), findsOneWidget); // Search

    // Secondary actions live in the overflow menu; the old add FAB is gone.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('uses a navigation rail on wide layouts', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await pumpUntil(tester, radarEmpty);

    // The wide layout swaps the bottom bar for a navigation rail, still on
    // Radar by default and still exposing the four destinations.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.widgetWithText(AppBar, 'Radar'), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('can switch to the Attention tab', (tester) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(const MyApp());
    await pumpUntil(tester, radarEmpty);

    await tester.tap(find.byIcon(Icons.inbox));
    // Assert the tab switched to the Attention surface (its app bar appears
    // immediately); the empty-state text depends on its async load.
    final attentionAppBar = find.widgetWithText(AppBar, 'Attention');
    await pumpUntil(tester, attentionAppBar);
    expect(attentionAppBar, findsOneWidget);
  });

  testWidgets('Teams opens from the overflow menu', (tester) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(const MyApp());
    await pumpUntil(tester, radarEmpty);

    await selectFromMenu(tester, 'Teams');

    // The overflow menu navigated to the Teams page (asserting the destination
    // app bar avoids depending on its data load, which the pushed page fetches
    // asynchronously).
    final teamsAppBar = find.widgetWithText(AppBar, 'Teams');
    await pumpUntil(tester, teamsAppBar);
    expect(teamsAppBar, findsOneWidget);
  });

  testWidgets('Manage Tokens opens from the overflow menu', (tester) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(const MyApp());
    await pumpUntil(tester, radarEmpty);

    await selectFromMenu(tester, 'Manage tokens');

    final tokensAppBar = find.widgetWithText(AppBar, 'Manage Tokens');
    await pumpUntil(tester, tokensAppBar);
    expect(tokensAppBar, findsOneWidget);
  });
}
