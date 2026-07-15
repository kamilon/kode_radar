import 'package:flutter/material.dart';

import 'token_store.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tokens = await TokenStore.getTokens();
    if (!mounted) return;
    setState(() {
      _tokens = tokens;
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

    await TokenStore.deleteToken(token.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed "${token.label}".')));
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
    final subtitle = token.isDefault
        ? 'Default (used when no scoped token matches)'
        : 'Scope: ${token.scope}';
    return ListTile(
      leading: const Icon(Icons.key),
      title: Text(token.label),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () => _edit(token),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            color: Colors.red,
            onPressed: () => _delete(token),
          ),
        ],
      ),
    );
  }
}
