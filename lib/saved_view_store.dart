import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A saved Activity Feed filter combination.
class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    this.groups = const <String>{},
    this.teamId,
    this.mineOnly = false,
  });

  final String id;
  final String name;

  /// Selected type groups (empty = all kinds).
  final Set<String> groups;

  /// Selected team id (null = all teams).
  final String? teamId;
  final bool mineOnly;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'groups': groups.toList()..sort(),
    'teamId': teamId,
    'mineOnly': mineOnly,
  };

  factory SavedView.fromJson(Map json) {
    final rawGroups = json['groups'];
    final groups = <String>{};
    if (rawGroups is List) {
      for (final g in rawGroups) {
        if (g is String && g.isNotEmpty) groups.add(g);
      }
    }
    final rawId = json['id'];
    final rawName = json['name'];
    return SavedView(
      id: rawId is String && rawId.isNotEmpty
          ? rawId
          : DateTime.now().microsecondsSinceEpoch.toString(),
      name: rawName is String ? rawName : '',
      groups: groups,
      teamId: json['teamId'] is String ? json['teamId'] as String : null,
      mineOnly: json['mineOnly'] == true,
    );
  }
}

/// Persists the Activity Feed's saved filter views. Writes are serialized so
/// concurrent add/delete can't clobber one another.
class SavedViewStore {
  SavedViewStore._();

  static const String _key = 'saved_feed_views';

  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<List<SavedView>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return _readFrom(prefs);
  }

  /// Adds a view (trims the name, generates an id) and returns it. Throws if
  /// the trimmed name is empty.
  static Future<SavedView> add({
    required String name,
    Set<String> groups = const {},
    String? teamId,
    bool mineOnly = false,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Saved view name cannot be empty');
    }
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final views = _readFrom(prefs);
      final view = SavedView(
        id: '${DateTime.now().microsecondsSinceEpoch}-${views.length}',
        name: trimmed,
        groups: groups,
        teamId: teamId,
        mineOnly: mineOnly,
      );
      views.add(view);
      await _writeTo(prefs, views);
      return view;
    });
  }

  static Future<void> delete(String id) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final views = _readFrom(prefs)..removeWhere((v) => v.id == id);
      await _writeTo(prefs, views);
    });
  }

  static List<SavedView> _readFrom(SharedPreferences prefs) {
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final views = <SavedView>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is! Map) continue;
        // A stored view without a real id would get a fresh id on every read,
        // making it impossible to delete — skip it.
        final id = decoded['id'];
        if (id is! String || id.isEmpty) continue;
        final view = SavedView.fromJson(decoded);
        if (view.name.isNotEmpty) views.add(view);
      } catch (_) {
        // Skip malformed entries.
      }
    }
    return views;
  }

  static Future<void> _writeTo(
    SharedPreferences prefs,
    List<SavedView> views,
  ) async {
    await prefs.setStringList(
      _key,
      views.map((v) => jsonEncode(v.toJson())).toList(),
    );
  }
}
