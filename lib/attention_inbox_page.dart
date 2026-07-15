import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_http.dart';
import 'attention_service.dart';
import 'identity_store.dart';
import 'notification_service.dart';
import 'snooze_store.dart';

/// Shows a ranked list of items that need the user's attention across all
/// monitored repositories (PRs waiting on review, changes requested, stale PRs,
/// and errors). Supports snooze/dismiss and a "Mine" filter.
class AttentionInboxPage extends StatefulWidget {
  const AttentionInboxPage({super.key});

  @override
  State<AttentionInboxPage> createState() => _AttentionInboxPageState();
}

class _AttentionInboxPageState extends State<AttentionInboxPage> {
  List<AttentionItem> _items = const [];
  bool _loading = true;
  bool _mineOnly = false;
  bool _identitySet = false;
  String? _error;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<AttentionItem> get _visibleItems =>
      _mineOnly ? _items.where((i) => i.isMine).toList() : _items;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snoozed = await SnoozeStore.snoozedIds();
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      final items = await AttentionService.computeAll(
        client: AppHttp.client,
        snoozedIds: snoozed,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _identitySet = selfGithub.isNotEmpty || selfAdo.isNotEmpty;
        _lastChecked = DateTime.now();
        _loading = false;
      });
      unawaited(NotificationService.notifyNewAttention(items));
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
            icon: Icon(_mineOnly ? Icons.person : Icons.groups),
            tooltip: _mineOnly
                ? 'Showing yours — tap for all'
                : 'Show only mine',
            onPressed: _loading
                ? null
                : () => setState(() => _mineOnly = !_mineOnly),
          ),
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
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    final visible = _visibleItems;
    if (visible.isEmpty) return _buildEmptyState();

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(visible.length);
        return _buildItemTile(visible[index - 1]);
      },
    );
  }

  Widget _buildEmptyState() {
    final String message;
    if (_items.isEmpty) {
      message = 'Nothing needs your attention right now.';
    } else if (_mineOnly && !_identitySet) {
      message = 'Set your identity in People to use the "Mine" filter.';
    } else {
      message = 'None of the current items are yours.';
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(
          child: Icon(
            Icons.check_circle_outline,
            size: 56,
            color: Colors.green[400],
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(message, textAlign: TextAlign.center)),
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

  Widget _buildHeader(int count) {
    final noun = 'item${count == 1 ? '' : 's'}';
    final label = _mineOnly
        ? '$count $noun yours'
        : '$count $noun need${count == 1 ? 's' : ''} attention';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Text(
        '$label${_lastChecked == null ? '' : ' · checked ${_relativeTime(_lastChecked!)}'}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }

  Widget _buildItemTile(AttentionItem item) {
    final visual = _visualFor(item.category);
    return Dismissible(
      key: ValueKey(item.id),
      background: _swipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.blueGrey,
        icon: Icons.snooze,
        label: 'Snooze 1 day',
      ),
      secondaryBackground: _swipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.notifications_off,
        label: 'Dismiss',
      ),
      onDismissed: (direction) => _onDismissed(item, direction),
      child: ListTile(
        leading: Icon(visual.icon, color: visual.color),
        title: Text(item.title),
        subtitle: Text(item.subtitle),
        trailing: item.url != null
            ? const Icon(Icons.open_in_new, size: 16)
            : null,
        onTap: item.url == null ? null : () => _open(item.url!),
      ),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _onDismissed(AttentionItem item, DismissDirection direction) {
    final dismissForever = direction == DismissDirection.endToStart;
    // Remove synchronously so the dismissed widget is gone before the next
    // build, then persist the snooze in the background.
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
    final pending = dismissForever
        ? SnoozeStore.snooze(item.id)
        : SnoozeStore.snooze(item.id, forDuration: const Duration(days: 1));
    unawaited(pending);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(dismissForever ? 'Dismissed' : 'Snoozed for 1 day'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            // Ensure the snooze write finished before undoing, but never let a
            // persistence error prevent the undo/reload.
            try {
              await pending;
            } catch (_) {}
            await SnoozeStore.unsnooze(item.id);
            if (!mounted) return;
            await _load();
          },
        ),
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
