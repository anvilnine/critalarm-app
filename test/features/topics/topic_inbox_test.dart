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
}
