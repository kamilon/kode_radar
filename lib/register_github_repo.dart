import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RegisterGithubRepoPage extends StatefulWidget {
  const RegisterGithubRepoPage({super.key});

  @override
  State<RegisterGithubRepoPage> createState() => _RegisterGithubRepoPageState();
}

class _RegisterGithubRepoPageState extends State<RegisterGithubRepoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _repoNameController = TextEditingController();

  @override
  void dispose() {
    _ownerController.dispose();
    _repoNameController.dispose();
    super.dispose();
  }

  Future<void> _saveRepo(String owner, String repoName) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> repos = prefs.getStringList('github_repos') ?? [];
    repos.add(jsonEncode({'owner': owner, 'repoName': repoName}));
    await prefs.setStringList('github_repos', repos);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final owner = _ownerController.text;
      final repoName = _repoNameController.text;

      _saveRepo(owner, repoName).then((_) {
        if (!mounted) return; // Ensure the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repository saved successfully!')),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register GitHub Repository'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  labelText: 'Repository Owner',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the repository owner';
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
