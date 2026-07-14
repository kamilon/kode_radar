import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attention_service.dart';

class NotificationService {
  NotificationService._();

  static const String _seenKey = 'seen_attention';
  static const int _summaryNotificationId = 42001;
  static const String _channelId = 'attention_inbox';
  static const String _channelName = 'Attention Inbox';
  static const String _channelDescription =
      'Notifications for new Attention Inbox items';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Future<void>? _initFuture;

  static Future<void> init() async {
    if (_initialized || !_isSupportedPlatform) return;

    final existing = _initFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final initFuture = _initPlugin();
    _initFuture = initFuture;
    await initFuture;
  }

  static Future<void> notifyNewAttention(List<AttentionItem> items) async {
    try {
      final currentIds = items.map((item) => item.id).toSet();
      final prefs = await SharedPreferences.getInstance();
      // On the very first run there is no baseline, so seed silently instead of
      // notifying for every existing item.
      final firstRun = !prefs.containsKey(_seenKey);
      final seen = (prefs.getStringList(_seenKey) ?? const <String>[]).toSet();
      final newIds = firstRun ? <String>{} : diffNew(seen, currentIds);

      if (newIds.isNotEmpty) {
        final newItems = items
            .where((item) => newIds.contains(item.id))
            .toList(growable: false);
        await _showSummaryNotification(newItems);
      }

      await prefs.setStringList(_seenKey, currentIds.toList()..sort());
    } catch (e) {
      debugPrint('Failed to process attention notifications: $e');
    }
  }

  static Set<String> diffNew(Set<String> seen, Iterable<String> current) =>
      current.toSet().difference(seen);

  static Future<void> _initPlugin() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _showSummaryNotification(
    List<AttentionItem> newItems,
  ) async {
    try {
      if (newItems.isEmpty || !_isSupportedPlatform) return;

      await init();
      if (!_initialized) return;

      final details = _notificationDetails();
      if (details == null) return;

      await _plugin.show(
        _summaryNotificationId,
        _summaryTitle(newItems.length),
        _summaryBody(newItems),
        details,
      );
    } catch (e) {
      debugPrint('Failed to show attention notification: $e');
    }
  }

  static NotificationDetails? _notificationDetails() {
    if (!_isSupportedPlatform) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
          ),
        ),
      TargetPlatform.iOS => const NotificationDetails(
          iOS: DarwinNotificationDetails(),
        ),
      TargetPlatform.macOS => const NotificationDetails(
          macOS: DarwinNotificationDetails(),
        ),
      _ => null,
    };
  }

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }

  static String _summaryTitle(int count) =>
      count == 1 ? '1 item needs attention' : '$count items need attention';

  static String _summaryBody(List<AttentionItem> items) {
    final titles = items.take(3).map((item) => item.title).toList();
    final remaining = items.length - titles.length;
    if (remaining > 0) {
      titles.add('+$remaining more');
    }
    return titles.join('\n');
  }
}
