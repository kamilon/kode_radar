import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RegisterAdoRepoPage extends StatefulWidget {
  const RegisterAdoRepoPage({super.key});

  @override
  State<RegisterAdoRepoPage> createState() => _RegisterAdoRepoPageState();
}

class _RegisterAdoRepoPageState extends State<RegisterAdoRepoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _repoNameController = TextEditingController();

  @override
  void dispose() {
    _organizationController.dispose();
    _projectController.dispose();
    _repoNameController.dispose();
    super.dispose();
  }

  Future<void> _saveRepo(String organization, String project, String repoName) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> repos = prefs.getStringList('ado_repos') ?? [];
    repos.add(jsonEncode({'organization': organization, 'project': project, 'repoName': repoName}));
    await prefs.setStringList('ado_repos', repos);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final organization = _organizationController.text;
      final project = _projectController.text;
      final repoName = _repoNameController.text;

      _saveRepo(organization, project, repoName).then((_) {
        if (!mounted) return; // Ensure the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ADO Repository saved successfully!')),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register ADO Repository'),
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
                decoration: const InputDecoration(
                  labelText: 'Organization',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Project',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Repository Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the repository name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
