import 'package:critalarm/features/feature_guides/data/repositories/shared_prefs_feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPrefsFeatureGuideRepository> repo(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPrefsFeatureGuideRepository(
      await SharedPreferences.getInstance(),
    );
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

  // Home reloads its notices and asks the moment a guide ends, with no wait
  // for the write to finish, so the guide must already read as seen.
  test('a finished guide reads as seen straight away', () async {
    final cubit = FeatureGuideCubit(await repo({}));
    addTearDown(cubit.close);
    cubit
      ..requestIfNew(FeatureGuide.home)
      ..begin()
      ..finish();
    expect(cubit.hasSeenFirstGuide, isTrue);
  });
}
