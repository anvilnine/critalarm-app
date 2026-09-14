import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/features/paywall/data/repositories/dev_subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<DevProSwitch> makeSwitch([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    return DevProSwitch(await SharedPreferences.getInstance());
  }

  group('DevProSwitch', () {
    test('starts on the free tier when nothing was saved', () async {
      final proSwitch = await makeSwitch();
      expect(proSwitch.value, isFalse);
    });

    test('reads the saved choice on the next launch', () async {
      final proSwitch = await makeSwitch({'dev.pro_mode': true});
      expect(proSwitch.value, isTrue);
    });

    test('setPro writes the choice through to storage', () async {
      final proSwitch = await makeSwitch();
      await proSwitch.setPro(isPro: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dev.pro_mode'), isTrue);
    });

    test('setPro tells listeners', () async {
      final proSwitch = await makeSwitch();
      final seen = <bool>[];
      proSwitch.addListener(() => seen.add(proSwitch.value));

      await proSwitch.setPro(isPro: true);
      await proSwitch.setPro(isPro: false);

      expect(seen, [true, false]);
    });
  });

  group('DevSubscriptionRepository', () {
    test('reports the tier the switch is set to', () async {
      final proSwitch = await makeSwitch();
      final repository = DevSubscriptionRepository(proSwitch);

      final free = await repository.isProActive();
      expect(free.isSuccess(), isTrue);
      expect(free.getOrNull(), isFalse);

      await proSwitch.setPro(isPro: true);
      expect((await repository.isProActive()).getOrNull(), isTrue);
    });
  });
}
