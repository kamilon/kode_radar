import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'token_store.dart';

/// Form for creating a new token or editing an existing one.
///
/// Pops with `true` when a token was saved so the caller can refresh.
class AddEditTokenPage extends StatefulWidget {
  const AddEditTokenPage({super.key, this.existing});

  final TokenInfo? existing;

  @override
  State<AddEditTokenPage> createState() => _AddEditTokenPageState();
}

class _AddEditTokenPageState extends State<AddEditTokenPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _scopeController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();

  late String _provider;
  bool _autoAdd = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _provider = existing?.provider ?? TokenStore.providerGithub;
    _labelController.text = existing?.label ?? '';
    _scopeController.text = existing?.scope ?? '';
    _autoAdd = existing?.autoAdd ?? false;
    // Rebuild when the scope changes so the auto-add helper text / enablement
    // stays in sync.
    _scopeController.addListener(_onScopeChanged);
  }

  void _onScopeChanged() {
    setState(() {
      // Auto-add for Azure DevOps requires an organization scope.
      if (_provider == TokenStore.providerAdo &&
          _scopeController.text.trim().isEmpty) {
        _autoAdd = false;
      }
    });
  }

  @override
  void dispose() {
    _scopeController.removeListener(_onScopeChanged);
    _labelController.dispose();
    _scopeController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await TokenStore.updateToken(
          widget.existing!.copyWith(
            label: _labelController.text,
            scope: _scopeController.text,
            autoAdd: _autoAdd,
          ),
          secret: _secretController.text,
        );
      } else {
        await TokenStore.addToken(
          provider: _provider,
          label: _labelController.text,
          scope: _scopeController.text,
          secret: _secretController.text,
          autoAdd: _autoAdd,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save token: $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _createNewToken() async {
    if (_provider == TokenStore.providerGithub) {
      await _launch('https://github.com/settings/tokens/new');
      return;
    }

    var org = _scopeController.text.trim();
    if (org.isEmpty) {
      org = (await _promptForOrganization())?.trim() ?? '';
    }
    if (org.isEmpty) return;
    await _launch('https://dev.azure.com/$org/_usersSettings/tokens');
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<String?> _promptForOrganization() {
    String? organization;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Azure DevOps Organization'),
          content: TextField(
            autofocus: true,
            onChanged: (value) => organization = value,
            decoration: const InputDecoration(
              hintText: 'e.g., mycompany',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(organization),
              child: const Text('Open Token Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGithub = _provider == TokenStore.providerGithub;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Token' : 'Add Token')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditing)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Provider'),
                  subtitle: Text(widget.existing!.providerDisplayName),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _provider,
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TokenStore.providerGithub,
                      child: Text('GitHub'),
                    ),
                    DropdownMenuItem(
                      value: TokenStore.providerAdo,
                      child: Text('Azure DevOps'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _provider = value ?? TokenStore.providerGithub;
                    // Auto-add for Azure DevOps requires an organization scope;
                    // don't leave it enabled when switching to a state where the
                    // checkbox is disabled.
                    if (_provider == TokenStore.providerAdo &&
                        _scopeController.text.trim().isEmpty) {
                      _autoAdd = false;
                    }
                  }),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g., Personal, Acme Org',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a label'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _scopeController,
                decoration: InputDecoration(
                  labelText: isGithub
                      ? 'GitHub owner/org (optional)'
                      : 'Azure DevOps organization (optional)',
                  hintText: isGithub
                      ? 'e.g., acme — leave blank to use as default'
                      : 'e.g., acme — leave blank to use as default',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Leave the scope blank to make this the default token for all '
                '${isGithub ? 'GitHub' : 'Azure DevOps'} repositories that '
                'have no more specific match.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secretController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'Token (leave blank to keep current)'
                      : 'Token',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (!_isEditing && (value == null || value.trim().isEmpty)) {
                    return 'Please enter the token';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _createNewToken,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Create New Token'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final scopeEmpty = _scopeController.text.trim().isEmpty;
                final adoNeedsScope =
                    _provider == TokenStore.providerAdo && scopeEmpty;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _autoAdd,
                  onChanged: adoNeedsScope
                      ? null
                      : (value) => setState(() => _autoAdd = value ?? false),
                  title: const Text('Automatically add new repositories'),
                  subtitle: Text(
                    adoNeedsScope
                        ? 'Enter an organization scope above to enable auto-add '
                            'for Azure DevOps.'
                        : isGithub
                            ? 'Periodically adds repos this token can see'
                                '${scopeEmpty ? ' (all accessible repos)' : ' in "${_scopeController.text.trim()}"'}. '
                                'A removed repo will be re-added while this is on.'
                            : 'Periodically adds repos in the organization above. '
                                'A removed repo will be re-added while this is on.',
                  ),
                );
              }),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save' : 'Add Token'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
