import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/features/topics/domain/topic_message_order.dart';
import 'package:flutter_test/flutter_test.dart';

Message _m(String id, int time) =>
    Message(id: id, topic: 'prod-db', time: time);

List<String> _ids(Iterable<Message> messages) => [
  for (final m in messages) m.id,
];

void main() {
  group('newestFirst', () {
    test('puts 00:45 above 00:44 whatever order the list came in', () {
      final at0044 = _m('a', 44 * 60);
      final at0045 = _m('b', 45 * 60);
      expect(_ids(newestFirst([at0044, at0045])), ['b', 'a']);
      expect(_ids(newestFirst([at0045, at0044])), ['b', 'a']);
    });

    test('puts the newest three first in a longer list', () {
      final list = [
        _m('c', 30),
        _m('a', 10),
        _m('e', 50),
        _m('b', 20),
        _m('d', 40),
      ];
      expect(_ids(newestFirst(list).take(3)), ['e', 'd', 'c']);
    });

    test('keeps the later one in the list first when times are equal', () {
      expect(_ids(newestFirst([_m('a', 5), _m('b', 5), _m('c', 5)])), [
        'c',
        'b',
        'a',
      ]);
    });

    test('leaves the list it was given alone and handles none', () {
      final list = [_m('a', 1), _m('b', 2)];
      newestFirst(list);
      expect(_ids(list), ['a', 'b']);
      expect(newestFirst(const []), isEmpty);
    });
  });
}
