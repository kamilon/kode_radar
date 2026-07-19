import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:kode_radar/activity_event_store.dart';
import 'package:kode_radar/repo_detail_store.dart';
import 'package:kode_radar/manage_repos_page.dart';
import 'package:kode_radar/metric_store.dart';
import 'package:kode_radar/team_store.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    MetricStore.debugUseDatabase(db);
    ActivityEventStore.debugUseDatabase(db);
    RepoDetailStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('lists registered GitHub and ADO repositories', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'github_repos': [
        jsonEncode({'owner': 'flutter', 'repoName': 'flutter'}),
      ],
      'ado_repos': [
        jsonEncode({
          'organization': 'org',
          'project': 'proj',
          'repoName': 'repo',
        }),
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: ManageReposPage()));
    await tester.pumpAndSettle();

    expect(find.text('flutter/flutter'), findsOneWidget);
    expect(find.text('org/proj/repo'), findsOneWidget);
  });

  testWidgets('deletes a repository after confirmation and prunes its derived '
      'data', (WidgetTester tester) async {
    const repoKey = 'github:flutter/flutter';
    SharedPreferences.setMockInitialValues({
      'github_repos': [
        jsonEncode({'owner': 'flutter', 'repoName': 'flutter'}),
      ],
      'ado_repos': <String>[],
      'metric_history': jsonEncode({
        repoKey: [
          {
            'at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'openPrs': 1,
            'needsReview': 0,
            'activityScore': 1,
          },
        ],
      }),
      'teams': jsonEncode([
        {
          'id': 'team-1',
          'name': 'Platform',
          'repoKeys': [repoKey],
        },
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: ManageReposPage()));
    await tester.pumpAndSettle();

    expect(find.text('flutter/flutter'), findsOneWidget);

    // Tap the delete action and confirm in the dialog.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove repository?'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // The repo should be gone from the UI and from storage.
    expect(find.text('flutter/flutter'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('github_repos'), isEmpty);

    // Its derived trend history and team assignment should be pruned too.
    expect((await MetricStore.all()).containsKey(repoKey), isFalse);
    expect((await TeamStore.list()).single.repoKeys, isEmpty);
  });

  testWidgets('shows an empty state when no repositories are tracked', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ManageReposPage()));
    await tester.pumpAndSettle();

    expect(find.text('No repositories are being tracked yet.'), findsOneWidget);
  });
}
