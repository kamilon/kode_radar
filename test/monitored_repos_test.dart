import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/monitored_repos.dart';

void main() {
  test('parseMonitoredRepos builds github + ado references, sorted', () {
    final repos = parseMonitoredRepos(
      [
        jsonEncode({'owner': 'Zeta', 'repoName': 'web'}),
        jsonEncode({'owner': 'acme', 'repoName': 'api'}),
        jsonEncode({'bogus': true}),
      ],
      [
        jsonEncode({
          'organization': 'contoso',
          'project': 'Web',
          'repoName': 'site',
        }),
      ],
    );

    // Sorted case-insensitively by display name: acme/api, contoso/Web/site,
    // Zeta/web.
    expect(repos.map((r) => r.displayName).toList(), [
      'acme/api',
      'contoso/Web/site',
      'Zeta/web',
    ]);

    final github = repos.firstWhere((r) => r.provider == 'github');
    expect(github.repoKey, 'github:acme/api');
    expect(github.url, 'https://github.com/acme/api');

    final ado = repos.firstWhere((r) => r.provider == 'ado');
    expect(ado.repoKey, 'ado:contoso/web/site');
    expect(ado.url, 'https://dev.azure.com/contoso/Web/_git/site');
  });

  test('parseMonitoredRepos skips malformed records', () {
    final repos = parseMonitoredRepos(['not json', '{}'], const []);
    expect(repos, isEmpty);
  });
}
