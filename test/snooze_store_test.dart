import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/snooze_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trips a timed snooze and unsnooze', () async {
    await SnoozeStore.snooze('item-1', forDuration: const Duration(hours: 1));

    expect(await SnoozeStore.isSnoozed('item-1'), isTrue);
    expect(await SnoozeStore.snoozedIds(), contains('item-1'));

    await SnoozeStore.unsnooze('item-1');

    expect(await SnoozeStore.isSnoozed('item-1'), isFalse);
    expect(await SnoozeStore.snoozedIds(), isNot(contains('item-1')));
  });

  test('round-trips dismiss forever', () async {
    await SnoozeStore.snooze('item-2');

    expect(await SnoozeStore.isSnoozed('item-2'), isTrue);
    expect(await SnoozeStore.snoozedIds(), contains('item-2'));

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('snoozed_attention')!)
            as Map<String, dynamic>;
    expect(stored['item-2'], isNull);
  });

  test('pruneExpired removes expired entries and keeps active entries', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1000);

    final pruned = SnoozeStore.pruneExpired(<String, int?>{
      'expired': 999,
      'exactly-now': 1000,
      'future': 1001,
      'forever': null,
    }, now);

    expect(pruned, <String, int?>{'future': 1001, 'forever': null});
  });
}
