import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('adds and resolves a default (unscoped) token', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Personal',
      scope: '',
      secret: 'ghp_default',
    );
    expect(await TokenStore.resolveGithubSecret('anyowner'), 'ghp_default');
  });

  test('prefers a scoped token over the default (case-insensitive)', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Default',
      scope: '',
      secret: 'ghp_default',
    );
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Acme',
      scope: 'Acme',
      secret: 'ghp_acme',
    );
    expect(await TokenStore.resolveGithubSecret('acme'), 'ghp_acme');
    expect(await TokenStore.resolveGithubSecret('other'), 'ghp_default');
  });

  test(
    'per-repo override wins, and falls back when the token is gone',
    () async {
      await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Default',
        scope: '',
        secret: 'ghp_default',
      );
      final override = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Special',
        scope: 'someorg',
        secret: 'ghp_special',
      );

      expect(
        await TokenStore.resolveGithubSecret('acme', tokenId: override.id),
        'ghp_special',
      );

      await TokenStore.deleteToken(override.id);
      expect(
        await TokenStore.resolveGithubSecret('acme', tokenId: override.id),
        'ghp_default',
      );
    },
  );

  test('GitHub and ADO tokens are resolved independently', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'GH',
      scope: '',
      secret: 'gh',
    );
    expect(await TokenStore.resolveAdoSecret('org'), isNull);

    await TokenStore.addToken(
      provider: TokenStore.providerAdo,
      label: 'ADO',
      scope: 'org',
      secret: 'ado_secret',
    );
    expect(await TokenStore.resolveAdoSecret('org'), 'ado_secret');
  });

  test('updates metadata and optionally the secret', () async {
    final token = await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'A',
      scope: '',
      secret: 's1',
    );

    await TokenStore.updateToken(token.copyWith(label: 'B', scope: 'acme'));
    final tokens = await TokenStore.getTokensForProvider(
      TokenStore.providerGithub,
    );
    expect(tokens.single.label, 'B');
    expect(tokens.single.scope, 'acme');
    expect(await TokenStore.getSecret(token.id), 's1'); // unchanged

    await TokenStore.updateToken(token.copyWith(scope: 'acme'), secret: 's2');
    expect(await TokenStore.getSecret(token.id), 's2');
  });

  test('migrates legacy plaintext tokens into default tokens', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'github_token': 'legacy_gh',
      'ado_token': 'legacy_ado',
    });

    final tokens = await TokenStore.getTokens();
    expect(tokens.length, 2);
    expect(await TokenStore.resolveGithubSecret('any'), 'legacy_gh');
    expect(await TokenStore.resolveAdoSecret('anyorg'), 'legacy_ado');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('github_token'), isNull);
    expect(prefs.getString('ado_token'), isNull);
  });

  test('concurrent first-run reads do not duplicate migrated tokens', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'github_token': 'legacy_gh'});

    final results = await Future.wait([
      TokenStore.getTokens(),
      TokenStore.getTokens(),
      TokenStore.getTokens(),
    ]);

    for (final tokens in results) {
      expect(tokens.length, 1);
    }
    // And a subsequent read still shows exactly one token.
    expect((await TokenStore.getTokens()).length, 1);
  });

  test('persists the autoAdd flag', () async {
    final token = await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Acme',
      scope: 'acme',
      secret: 's',
      autoAdd: true,
    );
    expect((await TokenStore.getTokens()).single.autoAdd, isTrue);

    await TokenStore.updateToken(token.copyWith(autoAdd: false));
    expect((await TokenStore.getTokens()).single.autoAdd, isFalse);
  });
}
