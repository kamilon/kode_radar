import 'package:flutter/material.dart';

import 'app_http.dart';
import 'identity_service.dart';
import 'identity_store.dart';
import 'people_service.dart';
import 'person.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  List<Person> _people = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final people = await PeopleService.computeAll(client: AppHttp.client);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PeoplePage failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Something went wrong while loading people. Pull down to try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'Set your identity',
            onPressed: _editIdentity,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadPeople,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _loadPeople, child: _buildContent()),
    );
  }

  Future<void> _editIdentity() async {
    final gh = (await IdentityStore.selfGithubLogins()).join(', ');
    final ado = (await IdentityStore.selfAdoNames()).join(', ');
    if (!mounted) return;
    final ghController = TextEditingController(text: gh);
    final adoController = TextEditingController(text: ado);
    var detecting = false;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !detecting,
            child: AlertDialog(
              title: const Text('Your identity'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Marks "You" here and powers the Attention inbox\'s "Mine" '
                      'filter. Separate multiple entries with commas.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ghController,
                      decoration: const InputDecoration(
                        labelText: 'GitHub username(s)',
                        hintText: 'octocat, ...',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: adoController,
                      decoration: const InputDecoration(
                        labelText: 'Azure DevOps display name(s)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: detecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_search),
                        label: const Text('Detect from my tokens'),
                        onPressed: detecting
                            ? null
                            : () async {
                                setDialogState(() => detecting = true);
                                try {
                                  final result =
                                      await IdentityService.detectSelf(
                                        client: AppHttp.client,
                                        persist: false,
                                      );
                                  ghController.text = {
                                    ..._parseLogins(ghController.text),
                                    ...result.githubLogins,
                                  }.join(', ');
                                  adoController.text = {
                                    ..._parseNames(adoController.text),
                                    ...result.adoNames,
                                  }.join(', ');
                                } catch (e) {
                                  debugPrint('Identity detection failed: $e');
                                } finally {
                                  setDialogState(() => detecting = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: detecting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: detecting
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );
      if (saved == true) {
        await IdentityStore.setSelfGithubLogins(
          _parseLogins(ghController.text),
        );
        await IdentityStore.setSelfAdoNames(_parseNames(adoController.text));
        if (!mounted) return;
        await _loadPeople();
      }
    } finally {
      ghController.dispose();
      adoController.dispose();
    }
  }

  /// GitHub logins never contain whitespace, so split on commas or whitespace.
  Set<String> _parseLogins(String value) => value
      .split(RegExp(r'[,\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  /// Azure DevOps display names contain spaces, so split only on separators.
  Set<String> _parseNames(String value) => value
      .split(RegExp(r'[,\n;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  Widget _buildContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      );
    }

    if (_people.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No people found yet.', textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _people.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final person = _people[index];
        return ListTile(
          leading: CircleAvatar(child: Text(_initials(person.displayName))),
          title: Row(
            children: [
              Expanded(child: Text(person.displayName)),
              if (person.isSelf) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('You'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          subtitle: Text(
            _subtitle(person),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        );
      },
    );
  }

  String _subtitle(Person person) {
    final reviewText =
        '${person.reviewRequests} review request${person.reviewRequests == 1 ? '' : 's'}';
    final authoredText =
        '${person.authoredOpenPrs} open PR${person.authoredOpenPrs == 1 ? '' : 's'}';
    return '$reviewText · $authoredText · last active '
        '${_relativeTime(person.lastSeen)}';
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return 'unknown';
    final diff = DateTime.now().difference(value);
    if (diff.isNegative || diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    final months = diff.inDays ~/ 30;
    if (months < 12) return '${months}mo ago';
    return '${diff.inDays ~/ 365}y ago';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }
}
