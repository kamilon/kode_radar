import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openGitHubTokenSettings() async {
    const url = 'https://github.com/settings/tokens/new';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub token settings')),
      );
    }
  }

  Future<void> _openAzureDevOpsTokenSettings() async {
    if (!mounted) return;
    
    // Show dialog to ask for organization name
    String? organization = await _showOrganizationDialog();
    if (organization != null && organization.isNotEmpty) {
      final url = 'https://dev.azure.com/$organization/_usersSettings/tokens';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Azure DevOps token settings')),
        );
      }
    }
  }

  Future<String?> _showOrganizationDialog() async {
    String? organization;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Azure DevOps Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your Azure DevOps organization name:'),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => organization = value,
                decoration: const InputDecoration(
                  hintText: 'e.g., mycompany',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(organization),
              child: const Text('Open Token Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GitHub Token Section
            _buildTokenSection(
              title: 'GitHub Access Token',
              description: 'Required to access GitHub repositories, pull requests, and releases.',
              controller: _githubTokenController,
              hintText: 'Enter your GitHub token',
              permissions: [
                'repo (for private repositories)',
                'public_repo (for public repositories)',
                'read:org (if accessing organization repositories)',
              ],
              onCreateToken: _openGitHubTokenSettings,
              lifetimeRecommendations: [
                '90 days (recommended for regular use)',
                '30 days (for enhanced security)',
                '1 year (for CI/CD systems)',
              ],
            ),
            const SizedBox(height: 32),
            
            // Azure DevOps Token Section
            _buildTokenSection(
              title: 'Azure DevOps Access Token',
              description: 'Required to access Azure DevOps repositories, pipelines, and builds.',
              controller: _adoTokenController,
              hintText: 'Enter your Azure DevOps token',
              permissions: [
                'Code (read) - for repository access',
                'Build (read) - for build/pipeline information',
                'Project and team (read) - for project access',
              ],
              onCreateToken: _openAzureDevOpsTokenSettings,
              lifetimeRecommendations: [
                '90 days (recommended for regular use)',
                '30 days (for enhanced security)',
                '1 year (for automated systems)',
              ],
            ),
            const SizedBox(height: 32),
            
            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _saveTokens,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Save Tokens'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenSection({
    required String title,
    required String description,
    required TextEditingController controller,
    required String hintText,
    required List<String> permissions,
    required VoidCallback onCreateToken,
    required List<String> lifetimeRecommendations,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            // Token input field
            TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: hintText,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showTokenHelp(
                    title: title,
                    permissions: permissions,
                    lifetimeRecommendations: lifetimeRecommendations,
                  ),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            
            // Create token button
            OutlinedButton.icon(
              onPressed: onCreateToken,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Create New Token'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 8),
            
            // Quick permissions info
            ExpansionTile(
              title: const Text('Required Permissions'),
              initiallyExpanded: false,
              children: permissions.map((permission) => 
                ListTile(
                  leading: const Icon(Icons.check, size: 16),
                  title: Text(permission, style: const TextStyle(fontSize: 14)),
                  dense: true,
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showTokenHelp({
    required String title,
    required List<String> permissions,
    required List<String> lifetimeRecommendations,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$title Help'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Required Permissions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...permissions.map((permission) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $permission'),
                )),
                const SizedBox(height: 16),
                const Text(
                  'Recommended Token Lifetime:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...lifetimeRecommendations.map((recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $recommendation'),
                )),
                const SizedBox(height: 16),
                const Text(
                  'Security Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Keep your tokens secure and never share them'),
                const Text('• Use the minimum permissions needed'),
                const Text('• Regenerate tokens regularly'),
                const Text('• Delete unused tokens immediately'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
