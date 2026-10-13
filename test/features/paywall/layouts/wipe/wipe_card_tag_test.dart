import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the date tag on the leaving Wipe card', () {
    test('the card carries the date of the grey side while its rows are '
        'struck', () {
      expect(
        wipeCardTagFor(reversed: true, isStruck: true, date: '21 Oct'),
        '21 Oct',
      );
    });

    test('no tag while the card shows today\'s rows', () {
      expect(
        wipeCardTagFor(reversed: true, isStruck: false, date: '21 Oct'),
        isNull,
      );
    });

    test('the tag follows the strike: none before it, one from it on', () {
      String? at(double t, {bool isStill = false}) => wipeCardTagFor(
        reversed: true,
        isStruck: wipeLeavingStruckAt(t, isStill: isStill),
        date: '21 Oct',
      );
      expect(at(0), isNull);
      expect(at(wipeBackSweepEnd), isNull);
      expect(at(wipeBackStrikeAt), '21 Oct');
      expect(at(9), '21 Oct');
      // Nothing may move: the frame is the struck one, so it has the tag.
      expect(at(0, isStill: true), '21 Oct');
    });

    test('the shipped Wipe has no tag on its card', () {
      for (final isStruck in [true, false]) {
        expect(
          wipeCardTagFor(reversed: false, isStruck: isStruck, date: 'Free'),
          isNull,
        );
      }
    });
  });
}
