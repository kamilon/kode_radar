import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/ignore_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('get returns an empty set initially', () async {
    expect(await IgnoreStore.get(), isEmpty);
  });

  test('add and get roundtrip', () async {
    await IgnoreStore.add('github:owner/repo');

    expect(await IgnoreStore.get(), {'github:owner/repo'});
  });

  test('add is idempotent', () async {
    await IgnoreStore.add('github:owner/repo');
    await IgnoreStore.add('github:owner/repo');

    expect(await IgnoreStore.get(), {'github:owner/repo'});
  });

  test('addAll dedupes and skips empty strings', () async {
    await IgnoreStore.addAll([
      'github:owner/repo',
      '',
      'github:owner/repo',
      'ado:org/project/repo',
    ]);

    expect(await IgnoreStore.get(), {
      'github:owner/repo',
      'ado:org/project/repo',
    });
  });

  test('remove deletes an ignored key', () async {
    await IgnoreStore.addAll([
      'github:owner/repo',
      'ado:org/project/repo',
    ]);

    await IgnoreStore.remove('github:owner/repo');

    expect(await IgnoreStore.get(), {'ado:org/project/repo'});
  });
}
