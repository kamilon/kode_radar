import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/saved_view_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add, list, and delete round-trip', () async {
    expect(await SavedViewStore.list(), isEmpty);
    final view = await SavedViewStore.add(
      name: '  My PRs  ',
      groups: {'prs', 'reviews'},
      teamId: 'team-1',
      mineOnly: true,
    );
    expect(view.name, 'My PRs'); // trimmed

    final views = await SavedViewStore.list();
    expect(views, hasLength(1));
    expect(views.single.groups, {'prs', 'reviews'});
    expect(views.single.teamId, 'team-1');
    expect(views.single.mineOnly, isTrue);

    await SavedViewStore.delete(view.id);
    expect(await SavedViewStore.list(), isEmpty);
  });

  test('add rejects an empty name', () async {
    expect(
      () => SavedViewStore.add(name: '   '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('SavedView JSON round-trips', () {
    const view = SavedView(
      id: 'v1',
      name: 'View',
      groups: {'ci'},
      teamId: null,
      mineOnly: false,
    );
    final restored = SavedView.fromJson(view.toJson());
    expect(restored.id, 'v1');
    expect(restored.name, 'View');
    expect(restored.groups, {'ci'});
    expect(restored.teamId, isNull);
    expect(restored.mineOnly, isFalse);
  });

  test('fromJson tolerates malformed fields', () {
    final view = SavedView.fromJson({
      'name': 'X',
      'groups': ['prs', 42, ''],
      'teamId': 7,
      'mineOnly': 'yes',
    });
    expect(view.name, 'X');
    expect(view.groups, {'prs'});
    expect(view.teamId, isNull);
    expect(view.mineOnly, isFalse);
    expect(view.id, isNotEmpty);
  });
}
