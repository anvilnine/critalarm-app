import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/features/permissions/domain/entities/background_killer_makers.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceMaker both(String name) => DeviceMaker(manufacturer: name, brand: name);

void main() {
  group('makerFamilyFor', () {
    test(
      'every listed maker has a family, except vivo, which has no guide',
      () {
        final without = [
          for (final name in backgroundKillerMakers)
            if (makerFamilyFor(both(name)) == null) name,
        ];
        expect(without, ['vivo']);
      },
    );

    test('sub-brands go with their parent', () {
      expect(makerFamilyFor(both('Samsung')), MakerFamily.samsung);
      expect(makerFamilyFor(both('Xiaomi')), MakerFamily.xiaomi);
      expect(makerFamilyFor(both('Redmi')), MakerFamily.xiaomi);
      expect(makerFamilyFor(both('POCO')), MakerFamily.xiaomi);
      expect(makerFamilyFor(both('OPPO')), MakerFamily.oppo);
      expect(makerFamilyFor(both('realme')), MakerFamily.oppo);
      expect(makerFamilyFor(both('OnePlus')), MakerFamily.oppo);
      expect(makerFamilyFor(both('HUAWEI')), MakerFamily.huawei);
      expect(makerFamilyFor(both('HONOR')), MakerFamily.huawei);
    });

    test('a Redmi reports Xiaomi as its manufacturer and still maps', () {
      const redmi = DeviceMaker(manufacturer: 'Xiaomi', brand: 'Redmi');
      expect(makerFamilyFor(redmi), MakerFamily.xiaomi);
    });

    test('the manufacturer is enough when the brand is unknown', () {
      const realmeOnOppo = DeviceMaker(manufacturer: 'OPPO', brand: 'unknown');
      expect(makerFamilyFor(realmeOnOppo), MakerFamily.oppo);
    });

    test('the brand wins when the two names disagree', () {
      const honorOnHuawei = DeviceMaker(manufacturer: 'HUAWEI', brand: 'HONOR');
      expect(makerFamilyFor(honorOnHuawei), MakerFamily.huawei);
      const strange = DeviceMaker(manufacturer: 'Samsung', brand: 'Redmi');
      expect(makerFamilyFor(strange), MakerFamily.xiaomi);
    });

    test('names are trimmed and must match whole', () {
      expect(makerFamilyFor(both('  Samsung ')), MakerFamily.samsung);
      expect(makerFamilyFor(both('Samsung Electronics')), isNull);
      expect(makerFamilyFor(both('notxiaomi')), isNull);
    });

    test(
      'a stock phone, an unknown phone and an empty read have no family',
      () {
        expect(makerFamilyFor(both('Google')), isNull);
        expect(makerFamilyFor(both('motorola')), isNull);
        expect(makerFamilyFor(DeviceMaker.unknown), isNull);
      },
    );
  });
}
