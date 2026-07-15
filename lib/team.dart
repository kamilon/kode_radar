class Team {
  const Team({required this.id, required this.name, this.repoKeys = const {}});

  final String id;
  final String name;
  final Set<String> repoKeys;

  Team copyWith({String? id, String? name, Set<String>? repoKeys}) => Team(
    id: id ?? this.id,
    name: name ?? this.name,
    repoKeys: repoKeys ?? this.repoKeys,
  );

  Map<String, dynamic> toJson() {
    final sortedRepoKeys = repoKeys.toList()..sort();
    return {'id': id, 'name': name, 'repoKeys': sortedRepoKeys};
  }

  factory Team.fromJson(Map json) {
    final rawRepoKeys = json['repoKeys'];
    final repoKeys = <String>{};
    if (rawRepoKeys is List) {
      for (final entry in rawRepoKeys) {
        if (entry is String && entry.isNotEmpty) {
          repoKeys.add(entry);
        }
      }
    }

    final rawId = json['id'];
    final rawName = json['name'];
    return Team(
      id: rawId is String && rawId.isNotEmpty
          ? rawId
          : DateTime.now().microsecondsSinceEpoch.toString(),
      name: rawName is String ? rawName : '',
      repoKeys: repoKeys,
    );
  }
}
