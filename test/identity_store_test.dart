import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/identity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trips self GitHub logins and ADO names', () async {
    await IdentityStore.setSelfGithubLogins({' Alice ', 'BOB', ''});
    await IdentityStore.setSelfAdoNames({' Ada Lovelace ', 'Grace Hopper', ''});

    expect(await IdentityStore.selfGithubLogins(), {'alice', 'bob'});
    expect(await IdentityStore.selfAdoNames(), {
      'Ada Lovelace',
      'Grace Hopper',
    });

    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString('self_github_logins')!) as List<dynamic>,
      ['alice', 'bob'],
    );
    expect(
      jsonDecode(prefs.getString('self_ado_names')!) as List<dynamic>,
      ['Ada Lovelace', 'Grace Hopper'],
    );
  });
}
