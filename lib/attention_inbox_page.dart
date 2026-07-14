import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'attention_service.dart';

/// Shows a ranked list of items that need the user's attention across all
/// monitored repositories (PRs waiting on review, stale PRs, and errors).
class AttentionInboxPage extends StatefulWidget {
  const AttentionInboxPage({super.key});

  @override
  State<AttentionInboxPage> createState() => _AttentionInboxPageState();
}

class _AttentionInboxPageState extends State<AttentionInboxPage> {
  List<AttentionItem> _items = const [];
  bool _loading = true;
  String? _error;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await AttentionService.computeAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _lastChecked = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      debugPrint('AttentionInbox failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Something went wrong while loading your inbox. Pull down to try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attention'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green[400]),
          ),
          const SizedBox(height: 12),
          const Center(child: Text('Nothing needs your attention right now.')),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _lastChecked == null
                  ? 'Pull down to refresh.'
                  : 'Checked ${_relativeTime(_lastChecked!)} · pull down to refresh.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              '${_items.length} item${_items.length == 1 ? '' : 's'} '
              'need${_items.length == 1 ? 's' : ''} attention'
              '${_lastChecked == null ? '' : ' · checked ${_relativeTime(_lastChecked!)}'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          );
        }
        final item = _items[index - 1];
        final visual = _visualFor(item.category);
        return ListTile(
          key: ValueKey(item.id),
          leading: Icon(visual.icon, color: visual.color),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          trailing:
              item.url != null ? const Icon(Icons.open_in_new, size: 16) : null,
          onTap: item.url == null ? null : () => _open(item.url!),
        );
      },
    );
  }

  ({IconData icon, Color color}) _visualFor(String category) {
    switch (category) {
      case 'reviewRequested':
        return (icon: Icons.rate_review, color: Colors.orange);
      case 'changesRequested':
        return (icon: Icons.edit_note, color: Colors.red);
      case 'oldOpenPr':
        return (icon: Icons.schedule, color: Colors.blueGrey);
      case 'error':
      default:
        return (icon: Icons.error_outline, color: Colors.grey);
    }
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showOpenError(url);
      return;
    }

    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;
    if (!canLaunch) {
      _showOpenError(url);
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) _showOpenError(url);
  }

  void _showOpenError(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $url')),
    );
  }
}
