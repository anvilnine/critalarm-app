import 'package:critalarm/features/incidents/presentation/alarm_screen_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the ring time a screen reader says', () {
    test('under a minute has no number in it', () {
      expect(spokenRingTime(Duration.zero), 'Ringing for less than a minute');
      expect(
        spokenRingTime(const Duration(seconds: 59)),
        'Ringing for less than a minute',
      );
    });

    test('one minute is singular', () {
      expect(
        spokenRingTime(const Duration(minutes: 1)),
        'Ringing for 1 minute',
      );
      expect(
        spokenRingTime(const Duration(seconds: 119)),
        'Ringing for 1 minute',
      );
    });

    test('whole minutes, with the seconds dropped', () {
      expect(
        spokenRingTime(const Duration(minutes: 2, seconds: 14)),
        'Ringing for 2 minutes',
      );
      expect(
        spokenRingTime(const Duration(hours: 1, minutes: 15)),
        'Ringing for 75 minutes',
      );
    });

    test('it changes once a minute, not once a second', () {
      final spoken = {
        for (var s = 120; s < 180; s++) spokenRingTime(Duration(seconds: s)),
      };
      expect(spoken, {'Ringing for 2 minutes'});
    });

    test('a clock that runs behind the server reads as just started', () {
      expect(
        spokenRingTime(const Duration(seconds: -4)),
        'Ringing for less than a minute',
      );
    });
  });

  group('the announcement when the ringing screen appears', () {
    test('one alarm: the topic and the ring time', () {
      expect(
        ringingAnnouncement(
          topic: 'prod-db',
          ringTime: 'Ringing for 2 minutes',
          openAlarms: 1,
        ),
        'prod-db. Ringing for 2 minutes.',
      );
    });

    test('several alarms: the count comes last', () {
      expect(
        ringingAnnouncement(
          topic: 'prod-db',
          ringTime: 'Ringing for less than a minute',
          openAlarms: 3,
        ),
        'prod-db. Ringing for less than a minute. 3 alarms open.',
      );
    });

    test('no open list yet still names the topic', () {
      expect(
        ringingAnnouncement(
          topic: 'prod-db',
          ringTime: 'Ringing for 1 minute',
          openAlarms: 0,
        ),
        'prod-db. Ringing for 1 minute.',
      );
    });
  });

  test('the topic is said before the severity word', () {
    expect(
      spokenTopic(topic: 'prod-db', word: 'CRITICAL'),
      'prod-db, CRITICAL',
    );
  });

  group('the message card as one stop', () {
    test('title, body, then the time and tags', () {
      expect(
        spokenMessage(
          title: 'Disk full',
          body: '/var at 98%',
          meta: '03:12 / db',
        ),
        'Disk full\n/var at 98%\n03:12 / db',
      );
    });

    test('an empty part leaves no gap', () {
      expect(
        spokenMessage(title: 'Disk full', body: '/var at 98%', meta: ''),
        'Disk full\n/var at 98%',
      );
    });
  });
}
