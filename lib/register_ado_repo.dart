import 'package:flutter/material.dart';
import 'dart:convert';

import 'ignore_store.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';
import 'token_override_field.dart';

class RegisterAdoRepoPage extends StatefulWidget {
  const RegisterAdoRepoPage({
    super.key,
    this.editIndex,
    this.initialOrganization,
    this.initialProject,
    this.initialRepoName,
    this.initialTokenId,
  });

  /// Index of the repository being edited in the stored `ado_repos` list.
  /// When null the page operates in "add" mode and appends a new entry.
  final int? editIndex;
  final String? initialOrganization;
  final String? initialProject;
  final String? initialRepoName;
  final String? initialTokenId;

  @override
  State<RegisterAdoRepoPage> createState() => _RegisterAdoRepoPageState();
}

class _RegisterAdoRepoPageState extends State<RegisterAdoRepoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _repoNameController = TextEditingController();

  String? _tokenId;

  bool get _isEditing => widget.editIndex != null;

  @override
  void initState() {
    super.initState();
    _organizationController.text = widget.initialOrganization ?? '';
    _projectController.text = widget.initialProject ?? '';
    _repoNameController.text = widget.initialRepoName ?? '';
    _tokenId = widget.initialTokenId;
  }

  @override
  void dispose() {
    _organizationController.dispose();
    _projectController.dispose();
    _repoNameController.dispose();
    super.dispose();
  }

  Future<bool> _saveRepo(
    String organization,
    String project,
    String repoName,
  ) async {
    final Map<String, String> repo = {
      'organization': organization,
      'project': project,
      'repoName': repoName,
    };
    if (_tokenId != null && _tokenId!.isNotEmpty) {
      repo['tokenId'] = _tokenId!;
    }
    final encoded = jsonEncode(repo);
    final index = widget.editIndex;
    final newKey = RepoDiscoveryService.adoKey(organization, project, repoName);
    final added = await RepoStore.update(RepoStore.adoKey, (repos) {
      if (index != null && index >= 0 && index < repos.length) {
        repos[index] = encoded; // Replace the existing entry when editing.
        return true;
      }
      // Add mode: skip if the same repo is already tracked.
      for (final raw in repos) {
        try {
          final m = Map<String, String>.from(jsonDecode(raw) as Map);
          final key = RepoDiscoveryService.adoKey(
            m['organization'] ?? '',
            m['project'] ?? '',
            m['repoName'] ?? '',
          );
          if (key == newKey) return false; // duplicate
        } catch (_) {}
      }
      repos.add(encoded);
      return true;
    });
    if (added) {
      // Explicitly (re-)adding a repo overrides any prior "ignore".
      await IgnoreStore.remove(newKey);
    }
    return added;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final organization = _organizationController.text.trim();
      final project = _projectController.text.trim();
      final repoName = _repoNameController.text.trim();

      _saveRepo(organization, project, repoName).then((added) {
        if (!mounted) return; // Ensure the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'ADO Repository updated successfully!'
                  : added
                  ? 'ADO Repository saved successfully!'
                  : 'That repository is already tracked.',
            ),
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit ADO Repository' : 'Register ADO Repository',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _organizationController,
                decoration: const InputDecoration(labelText: 'Organization'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the organization';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _projectController,
                decoration: const InputDecoration(labelText: 'Project'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the project';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repoNameController,
                decoration: const InputDecoration(labelText: 'Repository Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the repository name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TokenOverrideField(
                provider: TokenStore.providerAdo,
                initialTokenId: widget.initialTokenId,
                onChanged: (value) => _tokenId = value,
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text(_isEditing ? 'Save' : 'Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
