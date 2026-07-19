import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_http.dart';
import 'attention_service.dart';
import 'attention_store.dart';
import 'config_revision.dart';
import 'home_menu.dart';
import 'identity_store.dart';
import 'monitored_repos.dart';
import 'notification_service.dart';
import 'repo_store.dart';
import 'snooze_store.dart';
import 'sync_state_store.dart';

/// Shows a ranked list of items that need the user's attention across all
/// monitored repositories (PRs waiting on review, changes requested, stale PRs,
/// and errors). Supports snooze/dismiss and a "Mine" filter.
class AttentionInboxPage extends StatefulWidget {
  const AttentionInboxPage({super.key});

  @override
  State<AttentionInboxPage> createState() => _AttentionInboxPageState();
}

class _AttentionInboxPageState extends State<AttentionInboxPage> {
  /// The persisted snapshot, driven by the reactive [AttentionStore.watch]
  /// stream (instant cache on cold start; auto-updates when a refresh persists).
  /// NOT snooze-filtered — snooze is applied at display time via [_snoozedIds].
  List<AttentionItem> _streamItems = const [];
  StreamSubscription<List<AttentionItem>>? _itemsSub;

  /// This round's transient per-repo error markers. These are never persisted to
  /// the store (so a failed repo doesn't look "clean" and wipe its cache), so
  /// they're overlaid on the persisted snapshot here.
  List<AttentionItem> _errorItems = const [];

  /// Locally snoozed/dismissed ids applied at display time (mirrors
  /// [SnoozeStore]), so a just-made dismiss is honored immediately and an undo
  /// restores the item from the cache without a network reload.
  Set<String> _snoozedIds = <String>{};

  /// Bumped on every local snooze mutation (dismiss/undo). An in-flight [_load]
  /// captures this before reading [SnoozeStore] and only applies the fetched set
  /// if it hasn't changed since, so a concurrent dismiss/undo isn't clobbered by
  /// a stale read.
  int _snoozeGen = 0;

  /// A load (cache render + network refresh) is in flight. Gates the manual
  /// Refresh action so overlapping network fetches/DB writes can't stack on top
  /// of an in-flight refresh; the cache-first render still updates underneath.
  bool _refreshing = true;
  bool _mineOnly = false;
  String? _categoryFilter;
  bool _identitySet = false;
  String? _error;

  /// When the inbox last refreshed successfully from the network (persisted), so
  /// the "checked" label stays honest while showing stale cache offline.
  DateTime? _lastSynced;

  // Guards against a stale in-flight load applying after a newer one.
  int _loadSeq = 0;

  /// The rendered snapshot: the persisted stream items plus this round's error
  /// markers, minus locally snoozed/dismissed ids, ranked most-urgent first.
  List<AttentionItem> get _items => [
    ..._streamItems,
    ..._errorItems,
  ].where((i) => !_snoozedIds.contains(i.id)).toList()..sort(_compareItems);

  /// Most-urgent-first ordering (severity desc, then repo, then id) matching
  /// [AttentionStore]'s persisted order so the error overlay slots in stably.
  static int _compareItems(AttentionItem a, AttentionItem b) {
    final bySeverity = b.severity.compareTo(a.severity);
    if (bySeverity != 0) return bySeverity;
    final byRepo = a.repoDisplay.compareTo(b.repoDisplay);
    if (byRepo != 0) return byRepo;
    return a.id.compareTo(b.id);
  }

  /// Show the full-screen spinner only when a load is in flight and there's
  /// nothing cached to render yet; once items are on screen, content stays
  /// visible while the network refresh continues underneath.
  bool get _showSpinner => _refreshing && _items.isEmpty && _error == null;

  @override
  void initState() {
    super.initState();
    configRevision.addListener(_onConfigChanged);
    _load();
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    configRevision.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) _load();
  }

  /// (Re)subscribes the reactive cache stream. The first emission renders the
  /// cache instantly; later emissions (a refresh persisting, or a repo-delete
  /// pruning) update the list automatically.
  void _subscribe() {
    _itemsSub?.cancel();
    _itemsSub = AttentionStore.watch().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _streamItems = items;
          // A late cache emission should clear a stale error screen that a
          // failed refresh set before the cache arrived.
          if (items.isNotEmpty) _error = null;
        });
      },
      onError: (Object e) =>
          debugPrint('AttentionInbox watch stream error: $e'),
    );
  }

  /// Items after the "Mine" toggle only — drives the per-category chip counts.
  List<AttentionItem> get _mineFiltered =>
      AttentionService.applyFilters(_items, mineOnly: _mineOnly);

  List<AttentionItem> get _visibleItems => AttentionService.applyFilters(
    _items,
    mineOnly: _mineOnly,
    category: _categoryFilter,
  );

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final snoozeGen = _snoozeGen;
      final snoozed = await SnoozeStore.snoozedIds();
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      if (!mounted || seq != _loadSeq) return;

      // Apply the current snoozes and (re)subscribe the reactive cache stream so
      // the persisted snapshot renders instantly (cold start / offline). Reading
      // snoozes before subscribing avoids a flash of snoozed items on the first
      // emission. Skip the assignment if a local dismiss/undo raced this read
      // (the local set is already authoritative in that case).
      setState(() {
        if (_snoozeGen == snoozeGen) _snoozedIds = snoozed;
        _identitySet = selfGithub.isNotEmpty || selfAdo.isNotEmpty;
      });
      _subscribe();

      // Provenance label (survives restart/offline), set even for a clean inbox.
      final lastSynced = await SyncStateStore.lastSuccess(
        SyncStateStore.attentionScope,
      );
      if (!mounted || seq != _loadSeq) return;
      setState(() => _lastSynced = lastSynced);

      // Refresh from the network and persist the snapshot. Compute WITHOUT
      // snooze filtering so `save` sees each repo's true success/failure (a
      // snoozed-away item or a dismissed error marker must not make a repo look
      // "clean" and wipe its last-known-good cache); snooze is applied only when
      // rendering/notifying below. Persisting triggers the watch stream, which
      // updates `_streamItems`.
      final computed = await AttentionService.computeAll(
        client: AppHttp.client,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
      );
      if (!mounted || seq != _loadSeq) return;
      await AttentionStore.save(computed);
      if (!mounted || seq != _loadSeq) return;
      // Re-read snoozes now (a dismiss may have happened during the fetch) so a
      // just-dismissed item can't flicker back into the rendered snapshot.
      final freshSnoozeGen = _snoozeGen;
      final freshSnoozed = await SnoozeStore.snoozedIds();
      if (!mounted || seq != _loadSeq) return;
      // A successful sync = at least one monitored repo was fetched without an
      // error (it had real items or was cleanly empty). Compare the number of
      // errored repos (one error item each) to the monitored count so a
      // persistently-failing repo alongside an empty (healthy) inbox doesn't
      // freeze the "checked" label. Fully offline (every repo errored) = not ok.
      final erroredRepos = computed
          .where((i) => i.category == AttentionStore.errorCategory)
          .length;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || seq != _loadSeq) return;
      final monitoredCount = parseMonitoredRepos(
        prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
        prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
      ).length;
      final syncedOk = monitoredCount == 0 || erroredRepos < monitoredCount;
      if (syncedOk) {
        await SyncStateStore.markSuccess(SyncStateStore.attentionScope);
        if (!mounted || seq != _loadSeq) return;
      }
      // Overlay this round's error markers (never persisted) on the streamed
      // snapshot; snooze filtering is applied by the `_items` getter.
      final errors = computed
          .where((i) => i.category == AttentionStore.errorCategory)
          .toList();
      setState(() {
        if (_snoozeGen == freshSnoozeGen) _snoozedIds = freshSnoozed;
        _errorItems = errors;
        _identitySet = selfGithub.isNotEmpty || selfAdo.isNotEmpty;
        if (syncedOk) _lastSynced = DateTime.now();
        _refreshing = false;
      });
      // Notify on the fresh, snooze-filtered set (error items are additionally
      // excluded inside NotificationService).
      unawaited(
        NotificationService.notifyNewAttention(
          computed.where((i) => !freshSnoozed.contains(i.id)).toList(),
        ),
      );
    } catch (e) {
      debugPrint('AttentionInbox failed to load: $e');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        // Keep any cached items rendered by the stream rather than replacing
        // them with an error state; only show the error when we have nothing.
        if (_items.isEmpty) {
          _error =
              'Something went wrong while loading your inbox. Pull down to try again.';
        }
        _refreshing = false;
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
            onPressed: _showSpinner ? null : _toggleMine,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _load,
          ),
          const HomeMenuButton(),
        ],
      ),
      body: _showSpinner
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _refresh, child: _buildContent()),
    );
  }

  /// Pull-to-refresh handler. If a load is already in flight (e.g. the
  /// initial/config-driven load that this RefreshIndicator doesn't own), ignore
  /// the pull instead of starting a second concurrent network fetch; the
  /// in-flight load updates the list when it completes.
  Future<void> _refresh() async {
    if (_refreshing) return;
    await _load();
  }

  void _toggleMine() {
    setState(() => _mineOnly = !_mineOnly);
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
    final Widget list = visible.isEmpty
        ? _buildEmptyState()
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: visible.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader(visible.length);
              return _buildItemTile(visible[index - 1]);
            },
          );

    final filterBar = _buildFilterBar();
    if (filterBar == null) return list;
    return Column(
      children: [
        filterBar,
        Expanded(child: list),
      ],
    );
  }

  /// A horizontal row of category chips (with counts). The active filter is
  /// always shown (even at zero) so a selection is never stranded. Returns null
  /// when nothing passes the "Mine" filter, or when there is only one category
  /// and no active selection to clear.
  Widget? _buildFilterBar() {
    if (_mineFiltered.isEmpty) return null;
    final counts = AttentionService.categoryCounts(_mineFiltered);
    final present = AttentionService.categories
        .where((c) => (counts[c] ?? 0) > 0 || c == _categoryFilter)
        .toList();
    if (present.length < 2 && _categoryFilter == null) return null;
    final total = _mineFiltered.length;
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _filterChip(
              'All ($total)',
              selected: _categoryFilter == null,
              onSelected: () => setState(() => _categoryFilter = null),
            ),
            for (final c in present)
              _filterChip(
                '${AttentionService.categoryLabel(c)} (${counts[c] ?? 0})',
                selected: _categoryFilter == c,
                onSelected: () => setState(
                  () => _categoryFilter = _categoryFilter == c ? null : c,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    String label, {
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final String message;
    if (_items.isEmpty) {
      message = 'Nothing needs your attention right now.';
    } else if (_mineOnly && !_identitySet) {
      message = 'Set your identity in People to use the "Mine" filter.';
    } else if (_categoryFilter != null) {
      final label = AttentionService.categoryLabel(_categoryFilter!);
      message = _mineOnly
          ? 'None of your "$label" items are here right now.'
          : 'No "$label" items right now.';
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
            _lastSynced == null
                ? 'Pull down to refresh.'
                : 'Updated ${_relativeTime(_lastSynced!)} · pull down to refresh.',
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
        '$label${_lastSynced == null ? '' : ' · updated ${_relativeTime(_lastSynced!)}'}',
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
    // Add to the local snooze set so the item disappears before the next build
    // (the `_items` getter filters it out), then persist the snooze.
    setState(() {
      _snoozedIds = {..._snoozedIds, item.id};
      _snoozeGen++;
    });
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
            // persistence error prevent the undo.
            try {
              await pending;
            } catch (_) {}
            await SnoozeStore.unsnooze(item.id);
            if (!mounted) return;
            // Drop it from the local snooze set so it reappears from the cached
            // stream without a full network reload.
            setState(() {
              _snoozedIds = {..._snoozedIds}..remove(item.id);
              _snoozeGen++;
            });
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
