import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/notification_service.dart';

void main() {
  test('diffNew returns current ids not already seen', () {
    expect(
      NotificationService.diffNew(<String>{'a', 'b'}, <String>['b', 'c', 'c']),
      <String>{'c'},
    );
  });

  test('diffNew returns an empty set when all current ids are seen', () {
    expect(
      NotificationService.diffNew(<String>{'a', 'b'}, <String>['a', 'b']),
      isEmpty,
    );
  });

  group('shouldAdvanceBaseline', () {
    test('quiet hours defer (hold the baseline)', () {
      expect(
        NotificationService.shouldAdvanceBaseline(
          firstRun: false,
          inQuietHours: true,
        ),
        isFalse,
      );
    });

    test('first run always seeds even during quiet hours', () {
      expect(
        NotificationService.shouldAdvanceBaseline(
          firstRun: true,
          inQuietHours: true,
        ),
        isTrue,
      );
    });

    test('non-quiet advances (disabled toggle drops, no replay)', () {
      expect(
        NotificationService.shouldAdvanceBaseline(
          firstRun: false,
          inQuietHours: false,
        ),
        isTrue,
      );
    });
  });
}
