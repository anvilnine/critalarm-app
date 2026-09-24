import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/formatters/message_share_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('title, body, then the topic and time', () {
    const m = TopicDetailMessageItem(
      title: 'Disk full',
      timestamp: 'Sep 25 14:03',
      body: 'db-1 at 98%',
      source: '',
    );
    expect(
      messageShareText(m, 'prod-db'),
      'Disk full\ndb-1 at 98%\n\nprod-db · Sep 25 14:03',
    );
  });

  test('a message whose title is only the topic name skips it', () {
    const m = TopicDetailMessageItem(
      title: 'prod-db',
      timestamp: 'Sep 25 14:03',
      body: 'deploy done',
      source: '',
    );
    expect(
      messageShareText(m, 'prod-db'),
      'deploy done\n\nprod-db · Sep 25 14:03',
    );
  });
}
