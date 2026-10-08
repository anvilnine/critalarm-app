import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_list_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('creamCardFor', () {
    test('the widgets card goes first, then day 0, then the sign-in card', () {
      expect(
        creamCardFor(widgets: true, day0: true, accountBackup: true),
        HomeCreamCard.widgets,
      );
      expect(
        creamCardFor(widgets: false, day0: true, accountBackup: true),
        HomeCreamCard.day0,
      );
      expect(
        creamCardFor(widgets: false, day0: false, accountBackup: true),
        HomeCreamCard.accountBackup,
      );
    });

    test('nothing due shows nothing', () {
      expect(
        creamCardFor(widgets: false, day0: false, accountBackup: false),
        isNull,
      );
    });
  });

  group('showsOneTopicCard', () {
    bool shows({
      int topics = 1,
      bool closed = false,
      bool setupDone = true,
      HomeCardKind kind = HomeCardKind.idle,
    }) => showsOneTopicCard(
      topicCount: topics,
      isClosed: closed,
      isSetupDone: setupDone,
      cardKind: kind,
    );

    test('shows under the only topic once setup is done', () {
      expect(shows(), isTrue);
    });

    test('needs exactly one topic', () {
      expect(shows(topics: 0), isFalse);
      expect(shows(topics: 2), isFalse);
    });

    test('closing it keeps it away', () {
      expect(shows(closed: true), isFalse);
    });

    test('waits for setup to finish', () {
      expect(shows(setupDone: false), isFalse);
    });

    test('stays away while the card waits for the first message', () {
      expect(shows(kind: HomeCardKind.waiting), isFalse);
      expect(shows(kind: HomeCardKind.setup), isFalse);
    });
  });

  group('nextGlanceCount', () {
    final now = DateTime(2026, 10, 9, 12);
    DateTime ago(Duration d) => now.subtract(d);

    int next({
      required MessageTimes after,
      MessageTimes? before,
      bool front = true,
      int count = 0,
    }) => nextGlanceCount(
      count: count,
      before: before,
      after: after,
      isInFront: front,
      now: now,
    );

    test('the first build never glances', () {
      expect(next(after: {'a': ago(const Duration(seconds: 5))}), 0);
    });

    test('a newer message on a known topic glances', () {
      final before = {'a': ago(const Duration(hours: 1))};
      final after = {'a': ago(const Duration(seconds: 5))};
      expect(next(before: before, after: after), 1);
    });

    test('the same time does not glance', () {
      final times = {'a': ago(const Duration(hours: 1))};
      expect(next(before: times, after: Map.of(times)), 0);
    });

    test('an older time does not glance', () {
      final before = {'a': ago(const Duration(hours: 1))};
      final after = {'a': ago(const Duration(hours: 2))};
      expect(next(before: before, after: after), 0);
    });

    test('not in front keeps the count', () {
      final before = {'a': ago(const Duration(hours: 1))};
      final after = {'a': ago(const Duration(seconds: 5))};
      expect(next(before: before, after: after, front: false, count: 3), 3);
    });

    test('the count goes up from where it was', () {
      final before = {'a': ago(const Duration(hours: 1))};
      final after = {'a': ago(const Duration(seconds: 5))};
      expect(next(before: before, after: after, count: 4), 5);
    });

    test('a new topic with a fresh message glances', () {
      final after = {'new': ago(const Duration(seconds: 20))};
      expect(next(before: <String, DateTime>{}, after: after), 1);
    });

    test('a topic that appears with an old message stays quiet', () {
      final after = {'synced': ago(const Duration(days: 3))};
      expect(next(before: <String, DateTime>{}, after: after), 0);
    });

    test('several topics moving at once is still one glance', () {
      final before = {
        'a': ago(const Duration(hours: 2)),
        'b': ago(const Duration(hours: 2)),
      };
      final after = {
        'a': ago(const Duration(seconds: 9)),
        'b': ago(const Duration(seconds: 3)),
      };
      expect(next(before: before, after: after), 1);
    });
  });
}
