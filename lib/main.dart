import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'radar_page.dart';
import 'attention_inbox_page.dart';
import 'activity_feed_page.dart';
import 'search_page.dart';
import 'theme_controller.dart';
import 'auto_add_service.dart';
import 'token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // Import for HTTP requests
import 'dart:async'; // Import for Timer
import 'package:collection/collection.dart'; // Import for DeepCollectionEquality
import 'package:tray_manager/tray_manager.dart'; // Import tray_manager package
import 'package:window_manager/window_manager.dart'; // Import window_manager package
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import for local notifications

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the persisted light/dark/system theme preference; fall back to the
  // system default if storage is unavailable rather than failing to launch.
  try {
    await ThemeController.instance.load();
  } catch (e, stackTrace) {
    debugPrint('Failed to load theme preference: $e\n$stackTrace');
  }

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
  await _notificationsPlugin.initialize(settings: initializationSettings);
  // Android 13+ (API 33+) requires the runtime POST_NOTIFICATIONS grant.
  await _notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  if (_isDesktopPlatform) {
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
  }

  try {
    runApp(const MyApp());
    if (_isDesktopPlatform) {
      await _initializeSystemTray(); // Initialize the system tray
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error starting listeners: $e');
    }
    if (e is SocketException) {
      if (kDebugMode) {
        print(
          'SocketException: Check if the ports are already in use or if permissions are missing.',
        );
      }
    }
  }
}

/// Desktop platforms are the only ones with window/tray support; the app runs
/// on mobile (iOS/Android) without these.
bool get _isDesktopPlatform =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

Future<void> _initializeSystemTray() async {
  await trayManager.setIcon('assets/app_icon.png'); // Set the tray icon
  trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'show', label: 'Show App'),
        MenuItem(key: 'exit', label: 'Exit'),
      ],
    ),
  );

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
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kode Radar',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: ThemeController.instance.mode,
          home: const MyHomePage(title: 'Kode Radar Home Page'),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// The selected primary tab: 0 Attention, 1 Radar, 2 Activity, 3 Search.
  /// Radar is the default landing.
  int _selectedIndex = 1;

  /// Tabs the user has opened at least once. Each surface is built lazily the
  /// first time its tab is selected, then kept alive to preserve its state.
  final Set<int> _visited = {1};

  // Legacy per-repo PR/build/release/pipeline data, retained only to drive the
  // background new-PR notifications (compared against the previous snapshot);
  // it is no longer rendered.
  final Map<String, Map<String, List<String>>> _data = {
    'PRs': {},
    'Builds': {},
    'Releases': {},
    'Pipelines': {},
  };
  bool _isFetching = false; // Guards against overlapping data-load cycles
  Timer? _updateTimer; // Add a timer for periodic updates
  Timer? _autoAddTimer; // Timer for the auto-add discovery pass
  Timer? _autoAddInitialTimer; // One-shot startup auto-add pass
  bool _autoAddRunning = false; // Guards against overlapping auto-add passes
  final Map<String, Map<String, List<String>>> _previousData =
      {}; // Store previous data for comparison
  final Set<String> _notifiedItems = {}; // Track already notified items
  // Repos whose existing PRs have been recorded as a baseline; a repo's first
  // fetch is silent so newly-added repos don't spam notifications.
  final Set<String> _baselinedRepos = {};

  @override
  void initState() {
    super.initState();
    _loadNotifiedItems(); // Load notified items from storage
    _loadRepos(initialLoad: true); // Perform the initial load
    _startLiveUpdates(); // Start periodic updates
    _startAutoAdd(); // Start periodic auto-add of new repositories
  }

  @override
  void dispose() {
    _updateTimer?.cancel(); // Cancel the timer when the widget is disposed
    _autoAddTimer?.cancel();
    _autoAddInitialTimer?.cancel();
    super.dispose();
  }

  void _startLiveUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadRepos(initialLoad: false); // Reload repositories in the background
    });
  }

  void _startAutoAdd() {
    // Run shortly after startup (once the initial load has settled), then on a
    // longer interval than the live-data poll.
    _autoAddInitialTimer = Timer(const Duration(seconds: 8), _runAutoAdd);
    _autoAddTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _runAutoAdd(),
    );
  }

  Future<void> _runAutoAdd() async {
    if (_autoAddRunning) return; // Skip if a pass is already in flight.
    _autoAddRunning = true;
    try {
      final added = await AutoAddService.run();
      if (added > 0 && mounted) {
        await _loadRepos(initialLoad: false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto-add pass failed: $e');
      }
    } finally {
      _autoAddRunning = false;
    }
  }

  Future<void> _loadNotifiedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedItems = prefs.getStringList('notified_items') ?? [];
    _notifiedItems.addAll(notifiedItems);
    _baselinedRepos.addAll(prefs.getStringList('baselined_repos') ?? []);
  }

  Future<void> _saveNotifiedItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notified_items', _notifiedItems.toList());
  }

  Future<void> _saveBaselinedRepos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('baselined_repos', _baselinedRepos.toList());
  }

  Future<void> _loadRepos({required bool initialLoad}) async {
    // Prevent overlapping fetch cycles (a slow cycle plus the 15s timer).
    if (_isFetching) return;
    _isFetching = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> githubRepos =
          prefs.getStringList('github_repos') ?? [];
      final List<String> adoRepos = prefs.getStringList('ado_repos') ?? [];
      final Map<String, Map<String, List<String>>> newData = {
        'PRs': {},
        'Builds': {},
        'Releases': {},
        'Pipelines': {},
      };

      for (var repo in githubRepos) {
        try {
          final repoMap = Map<String, String>.from(jsonDecode(repo));
          final owner = repoMap['owner'];
          final repoName = repoMap['repoName'];
          if (owner == null || repoName == null) continue;
          final repoKey = 'GitHub: $owner/$repoName';
          await _fetchGithubData(
            owner,
            repoName,
            repoKey,
            newData,
            repoMap['tokenId'],
          );
        } catch (e) {
          // Skip a malformed entry rather than aborting the whole refresh.
          if (kDebugMode) {
            print('Skipping malformed github_repos entry: $e');
          }
        }
      }

      for (var repo in adoRepos) {
        try {
          final repoMap = Map<String, String>.from(jsonDecode(repo));
          final organization = repoMap['organization'];
          final project = repoMap['project'];
          final repoName = repoMap['repoName'];
          if (organization == null || project == null || repoName == null) {
            continue;
          }
          final repoKey = 'ADO: $organization/$project/$repoName';
          await _fetchAdoData(
            organization,
            project,
            repoName,
            repoKey,
            newData,
            repoMap['tokenId'],
          );
        } catch (e) {
          if (kDebugMode) {
            print('Skipping malformed ado_repos entry: $e');
          }
        }
      }

      if (mounted) {
        // _data feeds the background new-PR notifications only; it is no longer
        // rendered, so update it directly rather than via setState.
        if (initialLoad || !_isDataEqual(_data, newData)) {
          _previousData.clear();
          _previousData.addAll(_data); // Save the current data as previous data
          _data.clear();
          _data.addAll(newData); // only if it has changed
        }
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _fetchGithubData(
    String owner,
    String repoName,
    String repoKey,
    Map<String, Map<String, List<String>>> newData,
    String? tokenId,
  ) async {
    final token = await TokenStore.resolveGithubSecret(owner, tokenId: tokenId);
    await _fetchData(
      repoKey,
      'PRs',
      Uri.parse('https://api.github.com/repos/$owner/$repoName/pulls'),
      (data) async {
        final bool isBaselined = _baselinedRepos.contains(repoKey);
        final List<String> prNotifications = [];
        return Future.value(
          data.map((pr) {
            final title = pr['title'] as String? ?? 'No Title';
            final number = pr['number'] as int? ?? 0;
            final user = pr['user']?['login'] as String? ?? 'Unknown User';
            final comments = pr['comments'] as int? ?? 0;

            final notificationKey = 'GitHub:$repoKey:PR#$number';
            if (!_notifiedItems.contains(notificationKey)) {
              // Only notify once the repo has been baselined; the first fetch of
              // a newly-added repo records existing PRs silently.
              if (isBaselined) {
                prNotifications.add('New PR #$number by $user: $title');
              }
              _notifiedItems.add(notificationKey); // Mark as notified
            }

            return 'PR #$number by $user: $title ($comments comments)';
          }).toList(),
        ).then((prList) {
          if (!isBaselined) {
            _baselinedRepos.add(repoKey);
            _saveBaselinedRepos();
          }
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
      token,
    );
    await _fetchData(
      repoKey,
      'Releases',
      Uri.parse('https://api.github.com/repos/$owner/$repoName/releases'),
      (data) async => Future.value(
        data.map((release) {
          final name =
              release['name'] as String? ??
              'Unnamed Release'; // Safely access the name
          return name;
        }).toList(),
      ),
      true, // GitHub
      newData,
      token,
    );
  }

  Future<void> _fetchAdoData(
    String organization,
    String project,
    String repoName,
    String repoKey,
    Map<String, Map<String, List<String>>> newData,
    String? tokenId,
  ) async {
    final token = await TokenStore.resolveAdoSecret(
      organization,
      tokenId: tokenId,
    );
    await _fetchData(
      repoKey,
      'PRs',
      Uri.parse(
        'https://dev.azure.com/$organization/$project/_apis/git/repositories/$repoName/pullrequests?api-version=6.0',
      ),
      (data) async {
        final bool isBaselined = _baselinedRepos.contains(repoKey);
        final List<String> prNotifications = [];
        return Future.value(
          data.map((pr) {
            final title = pr['title'] as String? ?? 'No Title';
            final id = pr['pullRequestId'] as int? ?? 0;
            final creator =
                pr['createdBy']?['displayName'] as String? ?? 'Unknown Creator';
            final status = pr['status'] as String? ?? 'Unknown Status';

            final notificationKey = 'ADO:$repoKey:PR#$id';
            if (!_notifiedItems.contains(notificationKey)) {
              if (isBaselined) {
                prNotifications.add(
                  'New PR #$id by $creator: $title (Status: $status)',
                );
              }
              _notifiedItems.add(notificationKey); // Mark as notified
            }

            return 'PR #$id by $creator: $title (Status: $status)';
          }).toList(),
        ).then((prList) {
          if (!isBaselined) {
            _baselinedRepos.add(repoKey);
            _saveBaselinedRepos();
          }
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
      token,
    );
    await _fetchData(
      repoKey,
      'Builds',
      Uri.parse(
        'https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=6.0',
      ),
      (data) async {
        return await Future.wait(
          data.map((build) async {
            final name =
                build['definition']['name'] as String? ?? 'Unnamed Build';
            final requestedBy =
                build['requestedBy']?['displayName'] as String? ??
                'Unknown User';
            final buildId = build['id'] as int?;
            if (buildId != null) {
              final stages = await _fetchBuildStages(
                organization,
                project,
                buildId,
                token,
              );
              final stagesText = stages.map((stage) => '- $stage').join('\n');
              return '$name (Triggered by: $requestedBy)\nStages:\n$stagesText';
            }
            return '$name (Triggered by: $requestedBy)';
          }).toList(),
        );
      },
      false, // ADO
      newData,
      token,
    );
    await _fetchData(
      repoKey,
      'Pipelines',
      Uri.parse(
        'https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=6.0',
      ),
      (data) async => Future.value(
        data.map((pipeline) {
          final name =
              pipeline['name'] as String? ??
              'Unnamed Pipeline'; // Safely access the pipeline name
          return name;
        }).toList(),
      ),
      false, // ADO
      newData,
      token,
    );
  }

  Future<List<String>> _fetchBuildStages(
    String organization,
    String project,
    int buildId,
    String? token,
  ) async {
    if (token == null || token.isEmpty) return ['Token not set.'];

    try {
      final response = await http.get(
        Uri.parse(
          'https://dev.azure.com/$organization/$project/_apis/build/builds/$buildId/timeline?api-version=6.0',
        ),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode(':$token'))}',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseBody = jsonDecode(response.body);
        final List<dynamic> records = responseBody['records'] ?? [];
        return records
            .where(
              (record) => record['type'] == 'Task',
            ) // Filter for task records
            .map((record) {
              final name = record['name'] as String? ?? 'Unnamed Task';
              final result = record['result'] as String? ?? 'unknown';
              return '$name: $result';
            })
            .toList();
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
    String? token,
  ) async {
    if (token == null || token.isEmpty) {
      newData[category]![repoKey] = [
        'Token not set. Add or assign a token via "Manage tokens".',
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
          'Non-authoritative response received (Status: 203). Please check your permissions or token.',
        ];
      } else {
        newData[category]![repoKey] = [
          'Failed to fetch data (Status: ${response.statusCode})',
        ];
      }
    } catch (e) {
      newData[category]![repoKey] = ['Error fetching data: $e'];
    }
  }

  bool _isDataEqual(
    Map<String, Map<String, List<String>>> oldData,
    Map<String, Map<String, List<String>>> newData,
  ) {
    return const DeepCollectionEquality().equals(oldData, newData);
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
          interruptionLevel:
              InterruptionLevel.active, // Critical level for visibility
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build each surface lazily the first time its tab is opened, then keep it
    // alive (via IndexedStack) so scroll position and loaded data persist. The
    // GlobalKey keeps the surfaces' state when the layout switches between the
    // rail and the bottom bar across the width breakpoint (e.g. desktop
    // resize), which moves the IndexedStack to a different tree position.
    final pages = <Widget>[
      for (var i = 0; i < _navItems.length; i++)
        _visited.contains(i) ? _surfaceFor(i) : const SizedBox.shrink(),
    ];
    final body = IndexedStack(
      key: _shellBodyKey,
      index: _selectedIndex,
      children: pages,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // A navigation rail on wide layouts (tablet / desktop), a bottom
        // navigation bar on narrow ones (phone).
        if (constraints.maxWidth >= 640) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onSelectTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in _navItems)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onSelectTab,
            destinations: [
              for (final item in _navItems)
                NavigationDestination(icon: Icon(item.icon), label: item.label),
            ],
          ),
        );
      },
    );
  }

  static const List<({IconData icon, String label})> _navItems = [
    (icon: Icons.inbox, label: 'Attention'),
    (icon: Icons.radar, label: 'Radar'),
    (icon: Icons.dynamic_feed, label: 'Activity'),
    (icon: Icons.search, label: 'Search'),
  ];

  // Preserves the surfaces' state when the rail/bottom-bar layout swaps the
  // IndexedStack to a different position in the tree.
  final GlobalKey _shellBodyKey = GlobalKey();

  Widget _surfaceFor(int index) {
    switch (index) {
      case 0:
        return const AttentionInboxPage();
      case 1:
        return const RadarPage();
      case 2:
        return const ActivityFeedPage();
      default:
        return const SearchPage();
    }
  }

  void _onSelectTab(int index) {
    // The Search surface stays mounted (it's in the IndexedStack) and autofocus
    // leaves its keyboard up, so dismiss focus when moving between tabs.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
  }
}
