import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/team_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add, rename, setRepos, and delete roundtrip', () async {
    final team = await TeamStore.add('Platform');

    expect(team.name, 'Platform');
    expect((await TeamStore.list()).single.id, team.id);

    await TeamStore.rename(team.id, 'Ops');
    expect((await TeamStore.list()).single.name, 'Ops');

    await TeamStore.setRepos(team.id, {
      'github:owner/repo',
      'ado:org/project/repo',
    });
    expect((await TeamStore.list()).single.repoKeys, {
      'github:owner/repo',
      'ado:org/project/repo',
    });

    await TeamStore.delete(team.id);
    expect(await TeamStore.list(), isEmpty);
  });
}
