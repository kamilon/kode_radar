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

  test('removeRepoFromAll strips a repo key from every team', () async {
    final platform = await TeamStore.add('Platform');
    final infra = await TeamStore.add('Infra');
    await TeamStore.setRepos(platform.id, {
      'github:owner/repo',
      'ado:org/project/repo',
    });
    await TeamStore.setRepos(infra.id, {'github:owner/repo'});

    await TeamStore.removeRepoFromAll('github:owner/repo');

    final teams = await TeamStore.list();
    final updatedPlatform = teams.firstWhere((t) => t.id == platform.id);
    final updatedInfra = teams.firstWhere((t) => t.id == infra.id);
    expect(updatedPlatform.repoKeys, {'ado:org/project/repo'});
    expect(updatedInfra.repoKeys, isEmpty);
  });

  test('removeRepoFromAll ignores unknown or blank keys', () async {
    final team = await TeamStore.add('Platform');
    await TeamStore.setRepos(team.id, {'github:owner/repo'});

    await TeamStore.removeRepoFromAll('github:owner/missing');
    await TeamStore.removeRepoFromAll('   ');

    expect((await TeamStore.list()).single.repoKeys, {'github:owner/repo'});
  });
}
