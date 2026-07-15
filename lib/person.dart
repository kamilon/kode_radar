class Person {
  Person({
    required this.key,
    required this.displayName,
    Set<String> githubLogins = const <String>{},
    Set<String> adoNames = const <String>{},
    this.authoredOpenPrs = 0,
    this.reviewRequests = 0,
    this.lastSeen,
    this.isSelf = false,
  }) : githubLogins = Set.unmodifiable(githubLogins),
       adoNames = Set.unmodifiable(adoNames);

  final String key;
  final String displayName;
  final Set<String> githubLogins;
  final Set<String> adoNames;
  int authoredOpenPrs;
  int reviewRequests;
  DateTime? lastSeen;
  bool isSelf;
}
