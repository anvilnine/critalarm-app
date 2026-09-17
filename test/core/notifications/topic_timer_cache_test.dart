import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/notifications/topic_timer_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'writes one key per topic in the order the Kotlin store reads',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await TopicTimerCache(prefs).save(const <Topic>[
        Topic(
          name: 'prod',
          repeatIntervalS: 45,
          maxRingS: 1200,
          deskTimerS: 300,
        ),
      ]);

      expect(prefs.getString('topic_timers.prod'), '45|1200|300');
    },
  );

  test('drops keys for topics that are gone', () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = TopicTimerCache(prefs);

    await cache.save(
      const <Topic>[Topic(name: 'prod'), Topic(name: 'staging')],
    );
    await cache.save(const <Topic>[Topic(name: 'prod')]);

    expect(prefs.getString('topic_timers.prod'), isNotNull);
    expect(prefs.getString('topic_timers.staging'), isNull);
  });
}
