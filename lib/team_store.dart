import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'team.dart';

class TeamStore {
  TeamStore._();

  static const String _teamsKey = 'teams';

  static int _idSuffix = 0;
  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_idSuffix++}';

  static Future<List<Team>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return _readFrom(prefs);
  }

  static Future<Team> add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Team name cannot be empty');
    }
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final teams = _readFrom(prefs);
      final team = Team(id: _newId(), name: trimmed);
      teams.add(team);
      await _writeTo(prefs, teams);
      return team;
    });
  }

  static Future<void> rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final teams = _readFrom(prefs);
      final index = teams.indexWhere((team) => team.id == id);
      if (index == -1) return;
      teams[index] = teams[index].copyWith(name: trimmed);
      await _writeTo(prefs, teams);
    });
  }

  static Future<void> delete(String id) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final teams = _readFrom(prefs)..removeWhere((team) => team.id == id);
      await _writeTo(prefs, teams);
    });
  }

  static Future<void> setRepos(String id, Set<String> repoKeys) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final teams = _readFrom(prefs);
      final index = teams.indexWhere((team) => team.id == id);
      if (index == -1) return;
      teams[index] = teams[index].copyWith(
        repoKeys: repoKeys
            .map((key) => key.trim())
            .where((key) => key.isNotEmpty)
            .toSet(),
      );
      await _writeTo(prefs, teams);
    });
  }

  /// Removes [repoKey] from every team's repo set (e.g. after the repo is
  /// removed from monitoring) so deleted repos don't linger in team
  /// assignments. Only writes when something actually changed.
  static Future<void> removeRepoFromAll(String repoKey) {
    final key = repoKey.trim();
    if (key.isEmpty) return Future<void>.value();
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final teams = _readFrom(prefs);
      var changed = false;
      for (var index = 0; index < teams.length; index++) {
        if (!teams[index].repoKeys.contains(key)) continue;
        teams[index] = teams[index].copyWith(
          repoKeys: teams[index].repoKeys.where((k) => k != key).toSet(),
        );
        changed = true;
      }
      if (changed) await _writeTo(prefs, teams);
    });
  }

  static List<Team> _readFrom(SharedPreferences prefs) {
    final raw = prefs.getString(_teamsKey);
    if (raw == null || raw.trim().isEmpty) return <Team>[];

    final decoded = _decode(raw);
    if (decoded is! List) {
      debugPrint('Skipping teams storage because it is not a JSON list.');
      return <Team>[];
    }

    final teams = <Team>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        debugPrint('Skipping malformed team entry: expected object.');
        continue;
      }
      final id = entry['id'];
      final name = entry['name'];
      if (id is! String ||
          id.isEmpty ||
          name is! String ||
          name.trim().isEmpty) {
        debugPrint('Skipping malformed team entry: missing id or name.');
        continue;
      }
      teams.add(Team.fromJson(entry));
    }
    return teams;
  }

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (error) {
      debugPrint('Failed to parse stored teams: $error');
      return null;
    }
  }

  static Future<void> _writeTo(
    SharedPreferences prefs,
    List<Team> teams,
  ) async {
    await prefs.setString(
      _teamsKey,
      jsonEncode(teams.map((team) => team.toJson()).toList()),
    );
  }
}
