import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_event_list.dart';
import 'app_http.dart';
import 'identity_store.dart';
import 'work_item_service.dart';

/// Shows open GitHub issues and Azure DevOps work items assigned to the user,
/// grouped by repository/project.
class WorkItemsPage extends StatefulWidget {
  const WorkItemsPage({super.key});

  @override
  State<WorkItemsPage> createState() => _WorkItemsPageState();
}

class _WorkItemsPageState extends State<WorkItemsPage> {
  List<WorkItem> _items = const [];
  bool _loading = true;
  bool _identitySet = false;
  bool _githubSkipped = false;
  int _failedSources = 0;
  String? _error;

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
      final selfGithub = await IdentityStore.selfGithubLogins();
      final result = await WorkItemService.computeAssigned(
        client: AppHttp.client,
        selfGithubLogins: selfGithub,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _failedSources = result.failedSources;
        _githubSkipped = result.githubSkippedNoIdentity;
        _identitySet = selfGithub.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      debugPrint('WorkItems failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading your work. Pull to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned to you'),
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
          : Column(
              children: [
                if (_error == null)
                  activitySourceNotice(failedSources: _failedSources),
                if (_error == null && _githubSkipped) _buildGithubHint(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
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
    if (_items.isEmpty) return _buildEmptyState();

    final rows = _buildRows(_items);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return row.header != null
            ? _groupHeader(row.header!)
            : _itemTile(row.item!);
      },
    );
  }

  Widget _buildEmptyState() {
    final String message;
    if (_failedSources > 0) {
      message = 'Couldn\'t load your work right now. Pull down to retry.';
    } else if (_identitySet) {
      message = 'Nothing is assigned to you right now.';
    } else {
      message =
          'No assigned work items. Set your GitHub identity in People to '
          'include GitHub issues (Azure DevOps work items assigned to your '
          'token appear automatically).';
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(
          child: Icon(
            _failedSources > 0
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size: 56,
            color: _failedSources > 0 ? Colors.grey : Colors.green[400],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildGithubHint() {
    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Set your GitHub identity in People to include assigned issues.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  List<_Row> _buildRows(List<WorkItem> items) {
    // Group by groupKey (github:owner/name vs ado:org/project) so identically
    // named GitHub repos and ADO projects never merge; within each group, keep
    // the most recently updated items first.
    final sorted = [...items]
      ..sort((a, b) {
        final byGroup = a.groupKey.compareTo(b.groupKey);
        if (byGroup != 0) return byGroup;
        final at = a.updatedAt;
        final bt = b.updatedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    final rows = <_Row>[];
    String? currentGroup;
    for (final item in sorted) {
      if (item.groupKey != currentGroup) {
        currentGroup = item.groupKey;
        rows.add(_Row.header(item.groupDisplay));
      }
      rows.add(_Row.item(item));
    }
    return rows;
  }

  Widget _groupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _itemTile(WorkItem item) {
    final updated = item.updatedAt;
    final subtitleParts = <String>[
      item.state,
      if (updated != null) 'updated ${activityRelativeTime(updated.toLocal())}',
    ];
    return ListTile(
      leading: Icon(
        item.provider == 'github' ? Icons.adjust : Icons.assignment_outlined,
        color: Colors.indigo,
      ),
      title: Text('${item.reference}: ${item.title}'),
      subtitle: Text(
        subtitleParts.join(' · '),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: item.url != null
          ? const Icon(Icons.open_in_new, size: 16)
          : null,
      onTap: item.url == null ? null : () => _open(item.url!),
    );
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

/// A row in the flattened list: either a group header or a work item.
class _Row {
  const _Row.header(this.header) : item = null;
  const _Row.item(this.item) : header = null;

  final String? header;
  final WorkItem? item;
}
