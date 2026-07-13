import 'package:flutter/material.dart';

import 'ignore_store.dart';

class ManageIgnoredPage extends StatefulWidget {
  const ManageIgnoredPage({super.key});

  @override
  State<ManageIgnoredPage> createState() => _ManageIgnoredPageState();
}

class _ManageIgnoredPageState extends State<ManageIgnoredPage> {
  List<String> _ignored = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ignored = (await IgnoreStore.get()).toList()..sort();
    if (!mounted) return;
    setState(() {
      _ignored = ignored;
      _isLoading = false;
    });
  }

  String _titleFor(String key) {
    if (key.startsWith('github:')) {
      final path = key.substring('github:'.length);
      final parts = path.split('/');
      if (parts.length == 2 && parts.every((part) => part.isNotEmpty)) {
        return path;
      }
    }

    if (key.startsWith('ado:')) {
      final path = key.substring('ado:'.length);
      final parts = path.split('/');
      if (parts.length == 3 && parts.every((part) => part.isNotEmpty)) {
        return path;
      }
    }

    return key;
  }

  String? _subtitleFor(String key) {
    if (key.startsWith('github:')) {
      final parts = key.substring('github:'.length).split('/');
      if (parts.length == 2 && parts.every((part) => part.isNotEmpty)) {
        return 'GitHub';
      }
    }

    if (key.startsWith('ado:')) {
      final parts = key.substring('ado:'.length).split('/');
      if (parts.length == 3 && parts.every((part) => part.isNotEmpty)) {
        return 'Azure DevOps';
      }
    }

    return null;
  }

  Future<void> _unignore(String key) async {
    final label = _titleFor(key);
    await IgnoreStore.remove(key);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Un-ignored "$label".')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ignored Repositories')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_ignored.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No ignored repositories.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _ignored.map(_buildIgnoredTile).toList(),
    );
  }

  Widget _buildIgnoredTile(String key) {
    final subtitle = _subtitleFor(key);
    return ListTile(
      leading: const Icon(Icons.block),
      title: Text(_titleFor(key)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Un-ignore',
        onPressed: () => _unignore(key),
      ),
    );
  }
}
