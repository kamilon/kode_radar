import 'package:flutter/foundation.dart';

/// A process-wide signal that the monitored repositories, access tokens, teams,
/// or identity changed. The live home surfaces (Radar, Attention, Activity,
/// Search) listen and reload so a change made from the overflow menu (or an
/// auto-add pass) is reflected immediately, without waiting for the next poll.
final ValueNotifier<int> configRevision = ValueNotifier<int>(0);

/// Notifies listeners that the monitored configuration changed.
void bumpConfigRevision() => configRevision.value++;
