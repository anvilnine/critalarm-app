import 'package:critalarm/features/tour/data/repositories/shared_prefs_tour_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPrefsTourRepository> repo(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPrefsTourRepository(await SharedPreferences.getInstance());
  }

  test('a fresh install has seen no guide', () async {
    final r = await repo({});
    expect(r.hasSeenGuide('home'), isFalse);
  });

  test('guides are remembered one by one', () async {
    final r = await repo({});
    await r.markGuidesSeen(['home']);
    await r.markGuidesSeen(['search', 'home']);
    expect(r.hasSeenGuide('home'), isTrue);
    expect(r.hasSeenGuide('search'), isTrue);
    expect(r.hasSeenGuide('settings'), isFalse);
  });

  test(
    'a device that sat through the old single tour has seen them all',
    () async {
      final r = await repo({'has_completed_showcase_tour': true});
      expect(r.hasSeenGuide('home'), isTrue);
      expect(r.hasSeenGuide('topic'), isTrue);
    },
  );
}
