import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/mute_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts empty', () async {
    expect(await MuteStore.mutedDisplays(), isEmpty);
  });

  test('mutes and unmutes a repo display', () async {
    await MuteStore.setMuted('acme/api', true);
    expect(await MuteStore.mutedDisplays(), {'acme/api'});
    expect(await MuteStore.isMuted('acme/api'), isTrue);
    expect(await MuteStore.isMuted('acme/web'), isFalse);

    await MuteStore.setMuted('acme/api', false);
    expect(await MuteStore.mutedDisplays(), isEmpty);
  });

  test('muting is idempotent and independent per repo', () async {
    await MuteStore.setMuted('acme/api', true);
    await MuteStore.setMuted('acme/api', true);
    await MuteStore.setMuted('org/proj/site', true);
    expect(await MuteStore.mutedDisplays(), {'acme/api', 'org/proj/site'});

    await MuteStore.remove('acme/api');
    expect(await MuteStore.mutedDisplays(), {'org/proj/site'});
  });
}
