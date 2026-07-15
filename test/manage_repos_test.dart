import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/manage_repos_page.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
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

  testWidgets('deletes a repository after confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'github_repos': [
        jsonEncode({'owner': 'flutter', 'repoName': 'flutter'}),
      ],
      'ado_repos': <String>[],
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
