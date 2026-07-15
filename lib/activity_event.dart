/// The kinds of activity the feed normalizes across providers.
///
/// Stored as plain strings (mirroring the string-category style used elsewhere,
/// e.g. `AttentionItem.category`) so events serialize trivially and are easy to
/// group/filter in the UI.
abstract final class ActivityType {
  static const String prOpened = 'prOpened';
  static const String prMerged = 'prMerged';
  static const String prClosed = 'prClosed';
  static const String reviewSubmitted = 'reviewSubmitted';
  static const String push = 'push';
  static const String release = 'release';
  static const String ciFailed = 'ciFailed';

  /// The coarse group a type belongs to, used for the feed's filter chips.
  /// One of: `prs`, `reviews`, `ci`, `releases`, `pushes`.
  static String groupOf(String type) {
    switch (type) {
      case prOpened:
      case prMerged:
      case prClosed:
        return groupPrs;
      case reviewSubmitted:
        return groupReviews;
      case ciFailed:
        return groupCi;
      case release:
        return groupReleases;
      case push:
        return groupPushes;
      default:
        return groupPrs;
    }
  }

  static const String groupPrs = 'prs';
  static const String groupReviews = 'reviews';
  static const String groupCi = 'ci';
  static const String groupReleases = 'releases';
  static const String groupPushes = 'pushes';

  /// All groups in display order (used to render filter chips consistently).
  static const List<String> groups = [
    groupPrs,
    groupReviews,
    groupCi,
    groupReleases,
    groupPushes,
  ];

  static String groupLabel(String group) {
    switch (group) {
      case groupPrs:
        return 'PRs';
      case groupReviews:
        return 'Reviews';
      case groupCi:
        return 'CI';
      case groupReleases:
        return 'Releases';
      case groupPushes:
        return 'Pushes';
      default:
        return group;
    }
  }
}

/// A single normalized activity event shown in the Activity Feed.
///
/// Providers (GitHub events/Actions, Azure DevOps PRs/pushes/builds) are
/// normalized to this one shape so the feed is provider-agnostic.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.provider,
    required this.repoKey,
    required this.repoDisplay,
    required this.actor,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    this.url,
    this.isMine = false,
  });

  /// Stable identity (provider event/PR/build id where available) so the feed
  /// can de-duplicate overlapping fetches and use it as a list key.
  final String id;

  /// One of the [ActivityType] constants.
  final String type;

  /// `github` or `ado`.
  final String provider;

  /// Repo identity key ([RepoDiscoveryService.githubKey]/`adoKey`) used to
  /// filter the feed by team.
  final String repoKey;

  /// Human-readable repo label (e.g. `owner/name`).
  final String repoDisplay;

  /// Who performed the action (GitHub login / ADO display name); may be empty.
  final String actor;

  final String title;
  final String subtitle;

  /// When the event occurred (UTC).
  final DateTime occurredAt;

  final String? url;

  /// True when [actor] matches the current user's stored identity.
  final bool isMine;

  String get group => ActivityType.groupOf(type);
}
