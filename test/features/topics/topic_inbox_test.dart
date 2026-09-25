import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/topics/domain/topic_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('topicPreview', () {
    test('title leads the body', () {
      const m = Message(
        id: 'a',
        topic: 't',
        title: 'Disk full',
        message: 'db-1 at 98%',
      );
      expect(topicPreview(m), 'Disk full: db-1 at 98%');
    });

    test('no title shows the body alone', () {
      const m = Message(id: 'a', topic: 't', message: 'deploy done');
      expect(topicPreview(m), 'deploy done');
    });

    test('line breaks fold into one line', () {
      const m = Message(id: 'a', topic: 't', message: 'line one\n\n  line two');
      expect(topicPreview(m), 'line one line two');
    });

    test('a blank title is ignored', () {
      const m = Message(id: 'a', topic: 't', title: '  ', message: 'x');
      expect(topicPreview(m), 'x');
    });
  });

  group('unreadCount', () {
    final read = DateTime.fromMillisecondsSinceEpoch(1000 * 1000);

    test('counts only messages after the read mark', () {
      expect(unreadCount([999, 1000, 1001, 1500], read), 2);
    });

    test('a topic never marked counts nothing', () {
      expect(unreadCount([1, 2, 3], null), 0);
    });
  });

  group('orderTopics', () {
    List<String> order(
      List<String> names, {
      Set<String> pinned = const {},
      Set<String> muted = const {},
      Set<String> live = const {},
      Map<String, int> latestAt = const {},
    }) => orderTopics(
      names,
      pinned: pinned,
      muted: muted,
      live: live,
      latestAt: latestAt,
    );

    test('newest message first inside a group', () {
      expect(
        order(['a', 'b', 'c'], latestAt: {'a': 1, 'b': 3, 'c': 2}),
        ['b', 'c', 'a'],
      );
    });

    test('topics with no messages keep their order at the end', () {
      expect(order(['a', 'b', 'c'], latestAt: {'c': 5}), ['c', 'a', 'b']);
    });

    test('pinned go first, muted go last', () {
      expect(
        order(
          ['a', 'b', 'c', 'd'],
          pinned: {'c'},
          muted: {'a'},
          latestAt: {'a': 9, 'b': 1, 'c': 1, 'd': 2},
        ),
        ['c', 'd', 'b', 'a'],
      );
    });

    test('a live topic never sinks, even when muted', () {
      expect(
        order(['a', 'b'], muted: {'a'}, live: {'a'}, latestAt: {'a': 5}),
        ['a', 'b'],
      );
    });
  });
}
