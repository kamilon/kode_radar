import 'dart:async';

import 'package:flutter/material.dart';

import 'token_store.dart';
import 'token_health_service.dart';
import 'token_health_store.dart';
import 'add_edit_token_page.dart';

/// Lists the stored access tokens grouped by provider and lets the user add,
/// edit, and remove them.
class ManageTokensPage extends StatefulWidget {
  const ManageTokensPage({super.key});

  @override
  State<ManageTokensPage> createState() => _ManageTokensPageState();
}

class _ManageTokensPageState extends State<ManageTokensPage> {
  List<TokenInfo> _tokens = [];
  bool _isLoading = true;

  /// The last known verification result per token id (persisted across
  /// sessions), and which tokens are being verified right now.
  final Map<String, StoredTokenCheck> _checks = {};
  final Set<String> _checking = {};

  /// A per-token generation counter. Each verify captures the current value and
  /// only applies/persists its result if the value still matches — so a check
  /// that was superseded by a new verify, an edit, or a delete is discarded,
  /// even across the async windows those actions span.
  final Map<String, int> _verifyGen = {};

  /// Invalidates any in-flight check for [tokenId] (bumps its generation).
  void _invalidateCheck(String tokenId) {
    _verifyGen[tokenId] = (_verifyGen[tokenId] ?? 0) + 1;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tokens = await TokenStore.getTokens();
    final stored = await TokenHealthStore.all();
    if (!mounted) return;
    setState(() {
      _tokens = tokens;
      _checks
        ..clear()
        ..addAll(stored);
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditTokenPage()),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _edit(TokenInfo token) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditTokenPage(existing: token)),
    );
    if (saved == true) {
      // The secret may have changed, so invalidate any in-flight check and
      // drop the stale verification result.
      _invalidateCheck(token.id);
      _checks.remove(token.id);
      _checking.remove(token.id);
      await TokenHealthStore.remove(token.id);
      await _load();
    }
  }

  Future<void> _delete(TokenInfo token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove token?'),
          content: Text(
            'Remove the "${token.label}" token?\n\n'
            'Repositories that relied on it will fall back to a matching or '
            'default token, or show "Token not set".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    // Invalidate any in-flight check now, before the async delete window, so a
    // check completing during it can't re-create the removed entry.
    _invalidateCheck(token.id);
    await TokenStore.deleteToken(token.id);
    await TokenHealthStore.remove(token.id);
    await _load();
    if (!mounted) return;
    setState(() {
      _checks.remove(token.id);
      _checking.remove(token.id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed "${token.label}".')));
  }

  Future<void> _verify(TokenInfo token) async {
    // Take this check's generation; a later verify/edit/delete bumps it and
    // supersedes us.
    final gen = (_verifyGen[token.id] ?? 0) + 1;
    _verifyGen[token.id] = gen;
    setState(() {
      _checking.add(token.id);
      _checks.remove(token.id);
    });
    final result = await TokenHealthService.check(token);
    // Only the most recent request for this token may apply/persist its result
    // — a superseded check must not be applied or persisted (else it would
    // resurface on the next open).
    if (!mounted || _verifyGen[token.id] != gen) return;
    final now = DateTime.now();
    // Fire-and-forget the persist, but swallow a storage failure so it can't
    // surface as an unhandled async error.
    unawaited(
      TokenHealthStore.record(
        token.id,
        result,
        now: now,
      ).catchError((Object _) {}),
    );
    setState(() {
      _checking.remove(token.id);
      _checks[token.id] = StoredTokenCheck(
        health: result.health,
        checkedAt: now,
        account: result.account,
        message: result.message,
        rateLimitRemaining: result.rateLimit?.remaining,
        rateLimitResetAt: result.rateLimit?.resetAt,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tokens')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Add token',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_tokens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No tokens added yet.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add token'),
            ),
          ],
        ),
      );
    }

    final github = _tokens
        .where((t) => t.provider == TokenStore.providerGithub)
        .toList();
    final ado = _tokens
        .where((t) => t.provider == TokenStore.providerAdo)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('GitHub', github.length),
        if (github.isEmpty)
          _buildEmptySection('No GitHub tokens added.')
        else
          ...github.map(_buildTokenTile),
        const Divider(height: 24),
        _buildSectionHeader('Azure DevOps', ado.length),
        if (ado.isEmpty)
          _buildEmptySection('No Azure DevOps tokens added.')
        else
          ...ado.map(_buildTokenTile),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        '$title ($count)',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }

  Widget _buildTokenTile(TokenInfo token) {
    final scopeLine = token.isDefault
        ? 'Default (used when no scoped token matches)'
        : 'Scope: ${token.scope}';
    final isChecking = _checking.contains(token.id);
    final check = _checks[token.id];
    return ListTile(
      isThreeLine: check != null || isChecking,
      leading: const Icon(Icons.key),
      title: Text(token.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(scopeLine),
          if (isChecking)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Verifying…'),
            )
          else if (check != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildCheckStatus(check),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isChecking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.verified_user_outlined),
              tooltip: 'Check authentication',
              visualDensity: VisualDensity.compact,
              onPressed: () => _verify(token),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: () => _edit(token),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            color: Colors.red,
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(token),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckStatus(StoredTokenCheck check) {
    // A stored "authenticated" result only reflects the moment it was checked;
    // after a while the token may have been revoked, so de-emphasize old
    // successes rather than implying current validity.
    final stale =
        check.health == TokenHealth.valid &&
        DateTime.now().difference(check.checkedAt) > const Duration(hours: 24);
    final (IconData icon, Color color, String text) = switch (check.health) {
      TokenHealth.valid => (
        stale ? Icons.help_outline : Icons.check_circle,
        stale ? Colors.grey : Colors.green,
        check.account == null || check.account!.isEmpty
            ? 'Authenticated'
            : 'Authenticated as ${check.account}',
      ),
      TokenHealth.invalid => (
        Icons.cancel,
        Colors.red,
        check.message ?? 'The token was rejected.',
      ),
      TokenHealth.error => (
        Icons.error_outline,
        Colors.orange,
        check.message ?? 'The check could not be completed.',
      ),
    };
    final suffix = stale
        ? ' · checked ${_relativeTime(check.checkedAt)} (may be out of date)'
        : ' · checked ${_relativeTime(check.checkedAt)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$text$suffix', style: TextStyle(color: color)),
            ),
          ],
        ),
        if (check.rateLimitRemaining != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 22),
            child: Text(
              _rateLimitText(check),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  /// A one-line API rate-limit budget summary for a stored check, e.g.
  /// "GitHub REST API: 4823 left · resets in 41m". Only GitHub reports this
  /// budget; the count reflects the moment of the last check (see the
  /// "checked …" note on the status line above it).
  static String _rateLimitText(StoredTokenCheck check) {
    final buffer = StringBuffer(
      'GitHub REST API: ${check.rateLimitRemaining} left',
    );
    final reset = check.rateLimitResetAt;
    if (reset != null) {
      final until = reset.difference(DateTime.now());
      if (until.inSeconds > 0) {
        if (until.inMinutes < 1) {
          buffer.write(' · resets in ${until.inSeconds}s');
        } else if (until.inMinutes < 60) {
          buffer.write(' · resets in ${until.inMinutes}m');
        } else {
          buffer.write(' · resets in ${until.inHours}h');
        }
      }
    }
    return buffer.toString();
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
}
