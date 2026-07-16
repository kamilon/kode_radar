import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'radar_page.dart';
import 'attention_inbox_page.dart';
import 'activity_feed_page.dart';
import 'search_page.dart';
import 'theme_controller.dart';
import 'auto_add_service.dart';
import 'app_http.dart';
import 'attention_service.dart';
import 'identity_store.dart';
import 'snooze_store.dart';
import 'notification_service.dart';
import 'config_revision.dart';
import 'dart:async'; // Import for Timer
import 'package:tray_manager/tray_manager.dart'; // Import tray_manager package
import 'package:window_manager/window_manager.dart'; // Import window_manager package

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the persisted light/dark/system theme preference; fall back to the
  // system default if storage is unavailable rather than failing to launch.
  try {
    await ThemeController.instance.load();
  } catch (e, stackTrace) {
    debugPrint('Failed to load theme preference: $e\n$stackTrace');
  }

  // Initialize local notifications (requests the runtime permission where
  // required). All notifications flow through NotificationService.
  await NotificationService.init();

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

  bool _isPolling = false; // Guards against overlapping attention polls.
  Timer? _updateTimer; // Periodic background attention poll.
  Timer? _autoAddTimer; // Timer for the auto-add discovery pass.
  Timer? _autoAddInitialTimer; // One-shot startup auto-add pass.
  bool _autoAddRunning = false; // Guards against overlapping auto-add passes.

  @override
  void initState() {
    super.initState();
    _pollAttention(); // Seed the notification baseline and do the first poll.
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
    _updateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollAttention(),
    );
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
        // Newly discovered repos: refresh the surfaces now; the next poll
        // picks up any attention items they contain.
        bumpConfigRevision();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto-add pass failed: $e');
      }
    } finally {
      _autoAddRunning = false;
    }
  }

  /// Periodically checks every monitored repository for pull requests that need
  /// attention and notifies for newly-appeared ones. This reuses the Attention
  /// Inbox's detection and its notification policy (enablement, quiet hours,
  /// and de-duplication via [NotificationService]) so there is a single
  /// notification system, and it only fetches pull requests.
  Future<void> _pollAttention() async {
    if (_isPolling) return; // Avoid overlapping cycles (a slow poll + timer).
    _isPolling = true;
    try {
      final snoozed = await SnoozeStore.snoozedIds();
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      final items = await AttentionService.computeAll(
        client: AppHttp.client,
        snoozedIds: snoozed,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
      );
      await NotificationService.notifyNewAttention(items);
    } catch (e) {
      if (kDebugMode) {
        print('Attention poll failed: $e');
      }
    } finally {
      _isPolling = false;
    }
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
