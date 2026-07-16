import 'package:flutter/material.dart';

import 'register_github_repo.dart';
import 'register_ado_repo.dart';
import 'manage_repos_page.dart';
import 'manage_tokens_page.dart';
import 'work_items_page.dart';
import 'people_page.dart';
import 'teams_page.dart';
import 'preferences_page.dart';
import 'theme_controller.dart';
import 'config_revision.dart';

/// The shared "more" overflow menu shown on every home surface's app bar. It
/// reaches the secondary destinations — work items, people, teams, repository
/// and token management, appearance, and settings — plus the add-repository
/// flow, keeping the four primary tabs uncluttered.
class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) => _onSelected(context, value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'work', child: Text('Assigned to you')),
        PopupMenuItem(value: 'people', child: Text('People')),
        PopupMenuItem(value: 'teams', child: Text('Teams')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'addRepo', child: Text('Add repository…')),
        PopupMenuItem(value: 'repos', child: Text('Manage repositories')),
        PopupMenuItem(value: 'tokens', child: Text('Manage tokens')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'appearance', child: Text('Appearance')),
        PopupMenuItem(value: 'settings', child: Text('Settings')),
      ],
    );
  }

  void _onSelected(BuildContext context, String value) {
    final navigator = Navigator.of(context);
    switch (value) {
      case 'work':
        navigator.push(
          MaterialPageRoute(builder: (_) => const WorkItemsPage()),
        );
      case 'people':
        _pushThenRefresh(navigator, const PeoplePage());
      case 'teams':
        _pushThenRefresh(navigator, const TeamsPage());
      case 'addRepo':
        _showAddRepoSheet(context);
      case 'repos':
        _pushThenRefresh(navigator, const ManageReposPage());
      case 'tokens':
        _pushThenRefresh(navigator, const ManageTokensPage());
      case 'appearance':
        _showAppearancePicker(context);
      case 'settings':
        _pushThenRefresh(navigator, const PreferencesPage());
    }
  }

  /// Pushes a destination that can change the monitored configuration
  /// (repos / tokens / teams / identity / preferences) and, on return, signals
  /// the surfaces to reload.
  Future<void> _pushThenRefresh(NavigatorState navigator, Widget page) async {
    await navigator.push(MaterialPageRoute(builder: (_) => page));
    bumpConfigRevision();
  }

  void _showAddRepoSheet(BuildContext context) {
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add GitHub Repository'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pushThenRefresh(navigator, const RegisterGithubRepoPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add ADO Repository'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pushThenRefresh(navigator, const RegisterAdoRepoPage());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAppearancePicker(BuildContext context) async {
    // Capture the messenger before the await so the error path doesn't use a
    // possibly-defunct context.
    final messenger = ScaffoldMessenger.of(context);
    final current = ThemeController.instance.mode;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          for (final option in const [
            (ThemeMode.system, 'System'),
            (ThemeMode.light, 'Light'),
            (ThemeMode.dark, 'Dark'),
          ])
            ListTile(
              title: Text(option.$2),
              trailing: current == option.$1 ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(dialogContext, option.$1),
            ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await ThemeController.instance.setMode(selected);
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save appearance preference.')),
      );
    }
  }
}
