import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'register_github_repo.dart';
import 'register_ado_repo.dart';
import 'settings_page.dart'; // Import the settings page
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // Import for HTTP requests
import 'dart:async'; // Import for Timer
import 'package:collection/collection.dart'; // Import for DeepCollectionEquality
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs
import 'package:tray_manager/tray_manager.dart'; // Import tray_manager package
import 'package:window_manager/window_manager.dart'; // Import window_manager package
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import for local notifications

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
  );
  await _notificationsPlugin.initialize(initializationSettings);

  await windowManager.ensureInitialized(); // Initialize window manager
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    skipTaskbar: false,
    title: 'Kode Radar',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  try {
    runApp(const MyApp());
    await _initializeSystemTray(); // Initialize the system tray
  } catch (e) {
    if (kDebugMode) {
      print('Error starting listeners: $e');
    }
    if (e is SocketException) {
      if (kDebugMode) {
        print(
          'SocketException: Check if the ports are already in use or if permissions are missing.');
      }
    }
  }
}

Future<void> _initializeSystemTray() async {
  await trayManager.setIcon('assets/app_icon.png'); // Set the tray icon
  trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'show', label: 'Show App'),
    MenuItem(key: 'exit', label: 'Exit'),
  ]));

  trayManager.addListener(_TrayManagerListener());
}

class _TrayManagerListener with TrayListener {
  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu(); // Show context menu on tray icon click
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show') {
      // Bring the app window to the foreground
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit') {
      // Exit the application
      trayManager.destroy();
      exit(0);
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kode Radar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Kode Radar Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, Map<String, List<String>>> _data = {
    'PRs': {},
    'Builds': {},
    'Releases': {},
    'Pipelines': {},
  };
  bool _isLoading = true; // Add a loading state
  Timer? _updateTimer; // Add a timer for periodic updates
  final Map<String, Map<String, List<String>>> _previousData =
      {}; // Store previous data for comparison
  final Set<String> _notifiedItems = {}; // Track already notified items

  @override
  void initState() {
    super.initState();
    _loadNotifiedItems(); // Load notified items from storage
    _tabController = TabController(length: _data.keys.length, vsync: this);
    _loadRepos(initialLoad: true); // Perform the initial load
    _startLiveUpdates(); // Start periodic updates
  }

  @override
  void dispose() {
    _tabController.dispose();
    _updateTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void _startLiveUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadRepos(initialLoad: false); // Reload repositories in the background
    });
  }

  Future<void> _loadNotifiedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedItems = prefs.getStringList('notified_items') ?? [];
    _notifiedItems.addAll(notifiedItems);
  }

  Future<void> _saveNotifiedItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notified_items', _notifiedItems.toList());
  }

  Future<void> _loadRepos({required bool initialLoad}) async {
    if (initialLoad) {
      setState(() {
        _isLoading = true; // Show loading indicator only for the initial load
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> githubRepos = prefs.getStringList('github_repos') ?? [];
    final List<String> adoRepos = prefs.getStringList('ado_repos') ?? [];
    final Map<String, Map<String, List<String>>> newData = {
      'PRs': {},
      'Builds': {},
      'Releases': {},
      'Pipelines': {},
    };

    for (var repo in githubRepos) {
      final repoMap = Map<String, String>.from(jsonDecode(repo));
      final repoKey = 'GitHub: ${repoMap['owner']}/${repoMap['repoName']}';
      await _fetchGithubData(
          repoMap['owner']!, repoMap['repoName']!, repoKey, newData);
    }

    for (var repo in adoRepos) {
      final repoMap = Map<String, String>.from(jsonDecode(repo));
      final repoKey =
          'ADO: ${repoMap['organization']}/${repoMap['project']}/${repoMap['repoName']}';
      await _fetchAdoData(repoMap['organization']!, repoMap['project']!,
          repoMap['repoName']!, repoKey, newData);
    }

    if (mounted) {
      setState(() {
        if (initialLoad || !_isDataEqual(_data, newData)) {
          _previousData.clear();
          _previousData.addAll(_data); // Save the current data as previous data
          _data.clear();
          _data.addAll(newData); // only if it has changed
        }

        if (initialLoad) {
          _isLoading = false; // Hide loading indicator after the initial load
        }
      });
    }
  }

  Future<void> _fetchGithubData(String owner, String repoName, String repoKey,
      Map<String, Map<String, List<String>>> newData) async {
    await _fetchData(
      repoKey,
      'PRs',
      Uri.parse('https://api.github.com/repos/$owner/$repoName/pulls'),
      (data) async {
        final List<String> prNotifications = [];
        return Future.value(data.map((pr) {
          final title = pr['title'] as String? ?? 'No Title';
          final number = pr['number'] as int? ?? 0;
          final user = pr['user']?['login'] as String? ?? 'Unknown User';
          final comments = pr['comments'] as int? ?? 0;

          final notificationKey = 'GitHub:$repoKey:PR#$number';
          if (!_notifiedItems.contains(notificationKey)) {
            prNotifications.add('New PR #$number by $user: $title');
            _notifiedItems.add(notificationKey); // Mark as notified
          }

          return 'PR #$number by $user: $title ($comments comments)';
        }).toList())
            .then((prList) {
          // Trigger notifications
          for (final notification in prNotifications) {
            _showNotification('New Pull Request', notification);
          }
          _saveNotifiedItems(); // Save notified items to storage
          return prList;
        });
      },
      true, // GitHub
      newData,
    );
    await _fetchData(
      repoKey,
      'Releases',
      Uri.parse('https://api.github.com/repos/$owner/$repoName/releases'),
      (data) async => Future.value(data.map((release) {
        final name = release['name'] as String? ??
            'Unnamed Release'; // Safely access the name
        return name;
      }).toList()),
      true, // GitHub
      newData,
    );
  }

  Future<void> _fetchAdoData(
      String organization,
      String project,
      String repoName,
      String repoKey,
      Map<String, Map<String, List<String>>> newData) async {
    await _fetchData(
      repoKey,
      'PRs',
      Uri.parse(
          'https://dev.azure.com/$organization/$project/_apis/git/repositories/$repoName/pullrequests?api-version=6.0'),
      (data) async {
        final List<String> prNotifications = [];
        return Future.value(data.map((pr) {
          final title = pr['title'] as String? ?? 'No Title';
          final id = pr['pullRequestId'] as int? ?? 0;
          final creator =
              pr['createdBy']?['displayName'] as String? ?? 'Unknown Creator';
          final status = pr['status'] as String? ?? 'Unknown Status';

          final notificationKey = 'ADO:$repoKey:PR#$id';
          if (!_notifiedItems.contains(notificationKey)) {
            prNotifications
                .add('New PR #$id by $creator: $title (Status: $status)');
            _notifiedItems.add(notificationKey); // Mark as notified
          }

          return 'PR #$id by $creator: $title (Status: $status)';
        }).toList())
            .then((prList) {
          // Trigger notifications
          for (final notification in prNotifications) {
            _showNotification('New Pull Request', notification);
          }
          _saveNotifiedItems(); // Save notified items to storage
          return prList;
        });
      },
      false, // ADO
      newData,
    );
    await _fetchData(
      repoKey,
      'Builds',
      Uri.parse(
          'https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=6.0'),
      (data) async {
        return await Future.wait(data.map((build) async {
          final name =
              build['definition']['name'] as String? ?? 'Unnamed Build';
          final requestedBy =
              build['requestedBy']?['displayName'] as String? ?? 'Unknown User';
          final buildId = build['id'] as int?;
          if (buildId != null) {
            final stages =
                await _fetchBuildStages(organization, project, buildId);
            final stagesText = stages.map((stage) => '- $stage').join('\n');
            return '$name (Triggered by: $requestedBy)\nStages:\n$stagesText';
          }
          return '$name (Triggered by: $requestedBy)';
        }).toList());
      },
      false, // ADO
      newData,
    );
    await _fetchData(
      repoKey,
      'Pipelines',
      Uri.parse(
          'https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=6.0'),
      (data) async => Future.value(data.map((pipeline) {
        final name = pipeline['name'] as String? ??
            'Unnamed Pipeline'; // Safely access the pipeline name
        return name;
      }).toList()),
      false, // ADO
      newData,
    );
  }

  Future<List<String>> _fetchBuildStages(
      String organization, String project, int buildId) async {
    final token = await _getAdoToken();
    if (token == null) return ['Token not set.'];

    try {
      final response = await http.get(
        Uri.parse(
            'https://dev.azure.com/$organization/$project/_apis/build/builds/$buildId/timeline?api-version=6.0'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode(':$token'))}',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseBody = jsonDecode(response.body);
        final List<dynamic> records = responseBody['records'] ?? [];
        return records
            .where(
                (record) => record['type'] == 'Task') // Filter for task records
            .map((record) {
          final name = record['name'] as String? ?? 'Unnamed Task';
          final result = record['result'] as String? ?? 'unknown';
          return '$name: $result';
        }).toList();
      } else {
        return ['Failed to fetch stages (Status: ${response.statusCode})'];
      }
    } catch (e) {
      return ['Error fetching stages: $e'];
    }
  }

  Future<void> _fetchData(
    String repoKey,
    String category,
    Uri url,
    Future<List<String>> Function(List<dynamic>)
        parseData, // Ensure parseData is consistently async
    bool isGithub,
    Map<String, Map<String, List<String>>> newData,
  ) async {
    final token = isGithub ? await _getGithubToken() : await _getAdoToken();

    if (token == null) {
      newData[category]![repoKey] = [
        'Token not set. Please configure it in settings.'
      ];
      return;
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': isGithub
              ? 'Bearer $token' // Use Bearer for GitHub API
              : 'Basic ${base64Encode(utf8.encode(':$token'))}', // Use Basic for ADO API
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseBody = jsonDecode(response.body);

        // Ensure the response is a list or extract the correct data structure
        final List<dynamic> responseData = responseBody is List
            ? responseBody
            : (responseBody['value'] ?? responseBody) as List<dynamic>;

        // Await the async parseData function
        final parsedData = await parseData(responseData);
        newData[category]![repoKey] = parsedData;
      } else if (response.statusCode == 203) {
        newData[category]![repoKey] = [
          'Non-authoritative response received (Status: 203). Please check your permissions or token.'
        ];
      } else {
        newData[category]![repoKey] = [
          'Failed to fetch data (Status: ${response.statusCode})'
        ];
      }
    } catch (e) {
      newData[category]![repoKey] = ['Error fetching data: $e'];
    }
  }

  bool _isDataEqual(Map<String, Map<String, List<String>>> oldData,
      Map<String, Map<String, List<String>>> newData) {
    return const DeepCollectionEquality().equals(oldData, newData);
  }

  Future<String?> _getGithubToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('github_token');
  }

  Future<String?> _getAdoToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ado_token');
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pr_notifications', // Channel ID
      'PR Notifications', // Channel name
      channelDescription: 'Notifications for new PRs and comments',
      importance: Importance.high,
      priority: Priority.high,
      timeoutAfter: 30000, // Notification stays visible for 30 seconds
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true, // Ensure the alert is presented
      presentSound: true, // Ensure the sound is presented
      interruptionLevel: InterruptionLevel.active, // Critical level for visibility
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _data.keys.map((category) => Tab(text: category)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator()) // Show a loading indicator
          : TabBarView(
              controller: _tabController,
              children: _data.keys.map((category) {
                final categoryData = _data[category];
                if (categoryData == null || categoryData.isEmpty) {
                  return const Center(child: Text('No data available.'));
                }
                return _buildListView(categoryData);
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddRepoDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRepoDialog() {
    if (!mounted) return; // Ensure the widget is still mounted
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add GitHub Repository'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RegisterGithubRepoPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add ADO Repository'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RegisterAdoRepoPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView(Map<String, List<String>> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available.'));
    }
    return ListView.builder(
      itemCount: data.keys.length,
      itemBuilder: (context, index) {
        final repoKey = data.keys.elementAt(index);
        return ExpansionTile(
          title: Text(repoKey),
          children: data[repoKey]?.map((item) {
                if (repoKey.startsWith('ADO:') && item.contains('Stages:')) {
                  final parts = item.split('\nStages:\n');
                  final buildInfo = parts[0];
                  final stages = parts.length > 1 ? parts[1].split('\n') : [];
                  return ExpansionTile(
                    title: Row(
                      children: [
                        if (repoKey.startsWith('ADO:') &&
                            item.contains('Stages:')) ...[
                          Icon(
                            item.contains('succeeded')
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: item.contains('succeeded')
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(buildInfo),
                      ],
                    ),
                    children: stages.map((stage) {
                      final stageParts = stage.split(': ');
                      final stageName = stageParts[0];
                      final String stageResult = stageParts.length > 1
                          ? stageParts[1].toLowerCase()
                          : 'unknown';

                      IconData icon;
                      Color iconColor;

                      switch (stageResult) {
                        case 'succeeded':
                          icon = Icons.check_circle;
                          iconColor = Colors.green;
                          break;
                        case 'failed':
                          icon = Icons.cancel;
                          iconColor = Colors.red;
                          break;
                        case 'pending':
                          icon = Icons.hourglass_empty;
                          iconColor = Colors.orange;
                          break;
                        default:
                          icon = Icons.help_outline;
                          iconColor = Colors.grey;
                      }

                      return ListTile(
                        leading: Icon(icon, color: iconColor),
                        title: Text(stageName),
                      );
                    }).toList(),
                  );
                }
                final url = _getUrlForItem(repoKey, item);
                return GestureDetector(
                  onDoubleTap: () async {
                    if (url != null && await canLaunch(url)) {
                      await launch(url); // Open the URL in the default browser
                    }
                  },
                  child: ListTile(title: Text(item)),
                );
              }).toList() ??
              [const ListTile(title: Text('Loading...'))],
        );
      },
    );
  }

  String? _getUrlForItem(String repoKey, String item) {
    // Logic to generate or retrieve the URL for the given item
    if (repoKey.startsWith('GitHub:')) {
      final parts = repoKey.split(': ')[1].split('/');
      final owner = parts[0];
      final repoName = parts[1];
      if (item.startsWith('PR #')) {
        final prNumber = item.split(' ')[1].substring(1);
        return 'https://github.com/$owner/$repoName/pull/$prNumber';
      } else if (item.startsWith('Release:')) {
        return 'https://github.com/$owner/$repoName/releases';
      }
    } else if (repoKey.startsWith('ADO:')) {
      final parts = repoKey.split(': ')[1].split('/');
      final organization = parts[0];
      final project = parts[1];
      final repoName = parts[2];
      if (item.startsWith('PR #')) {
        final prId = item.split(' ')[1].substring(1);
        return 'https://dev.azure.com/$organization/$project/_git/$repoName/pullrequest/$prId';
      } else if (item.startsWith('Build:')) {
        return 'https://dev.azure.com/$organization/$project/_build';
      }
    }
    return null;
  }
}

Future<bool> canLaunch(String url) async {
  return await canLaunchUrl(Uri.parse(url));
}

Future<void> launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch $url';
  }
}
