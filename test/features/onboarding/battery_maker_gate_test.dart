import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/features/permissions/domain/entities/background_killer_makers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const listed = [
    'Samsung',
    'Xiaomi',
    'Redmi',
    'Poco',
    'Oppo',
    'Realme',
    'OnePlus',
    'Vivo',
    'Huawei',
    'Honor',
  ];

  group('the makers that kill background apps', () {
    test('the list holds exactly the ten, lower-cased', () {
      expect(
        backgroundKillerMakers,
        listed.map((maker) => maker.toLowerCase()).toSet(),
      );
    });

    for (final maker in listed) {
      test('$maker matches in any case and with spaces around it', () {
        for (final spelling in [
          maker,
          maker.toLowerCase(),
          maker.toUpperCase(),
          '  $maker ',
          '\t${maker.toUpperCase()}\n',
        ]) {
          expect(
            makerKillsBackgroundApps(DeviceMaker(manufacturer: spelling)),
            isTrue,
            reason: 'manufacturer "$spelling"',
          );
          expect(
            makerKillsBackgroundApps(DeviceMaker(brand: spelling)),
            isTrue,
            reason: 'brand "$spelling"',
          );
        }
      });
    }

    test('Google, Motorola, Nothing and an empty string do not match', () {
      for (final maker in ['Google', 'motorola', 'Nothing', '', '   ']) {
        expect(
          makerKillsBackgroundApps(
            DeviceMaker(manufacturer: maker, brand: maker),
          ),
          isFalse,
          reason: '"$maker"',
        );
      }
      expect(makerKillsBackgroundApps(DeviceMaker.unknown), isFalse);
    });

    test('either field is enough', () {
      // A Redmi or a Poco reports Xiaomi as its manufacturer and its own
      // name as its brand. Either way it is on the list.
      expect(
        makerKillsBackgroundApps(
          const DeviceMaker(manufacturer: 'Xiaomi', brand: 'Redmi'),
        ),
        isTrue,
      );
      // A sub-brand whose manufacturer is not listed still matches on brand.
      expect(
        makerKillsBackgroundApps(
          const DeviceMaker(manufacturer: 'BBK', brand: 'POCO'),
        ),
        isTrue,
      );
      // And a listed manufacturer with a brand nobody has heard of.
      expect(
        makerKillsBackgroundApps(
          const DeviceMaker(manufacturer: 'HUAWEI', brand: 'nova'),
        ),
        isTrue,
      );
    });

    test('a name that only contains a listed one does not match', () {
      for (final maker in ['Nothing Phone by OnePlus fans', 'notsamsung']) {
        expect(
          makerKillsBackgroundApps(DeviceMaker(manufacturer: maker)),
          isFalse,
          reason: '"$maker"',
        );
      }
    });

    test('the generic maker an emulator reports does not match', () {
      expect(
        makerKillsBackgroundApps(
          const DeviceMaker(manufacturer: 'Google', brand: 'google'),
        ),
        isFalse,
      );
      expect(
        makerKillsBackgroundApps(
          const DeviceMaker(manufacturer: 'unknown', brand: 'generic'),
        ),
        isFalse,
      );
    });
  });
}
