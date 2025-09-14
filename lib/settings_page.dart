import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _githubTokenController = TextEditingController();
  final TextEditingController _adoTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _githubTokenController.text = prefs.getString('github_token') ?? '';
      _adoTokenController.text = prefs.getString('ado_token') ?? '';
    });
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', _githubTokenController.text);
    await prefs.setString('ado_token', _adoTokenController.text);
    if (!mounted) return; // Ensure the widget is still mounted
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tokens saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GitHub Access Token', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _githubTokenController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your GitHub token',
              ),
              obscureText: true, // Obscure sensitive input
            ),
            const SizedBox(height: 16),
            const Text('ADO Access Token', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _adoTokenController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your ADO token',
              ),
              obscureText: true, // Obscure sensitive input
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveTokens,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
