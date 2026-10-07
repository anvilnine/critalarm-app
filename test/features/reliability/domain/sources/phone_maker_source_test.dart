import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/sources/phone_maker_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements MakerGuideStore {
  MakerGuideRecord record = MakerGuideRecord.none;

  @override
  MakerGuideRecord read() => record;

  @override
  Future<void> write(MakerGuideRecord next) async => record = next;
}

const _android = PlatformCapabilities(
  isWeb: false,
  platform: TargetPlatform.android,
);

final _done = DateTime.utc(2026, 10, 7, 9);

void main() {
  late _MemoryStore store;
  late FixedOsVersionReader os;

  PhoneMakerSource build({
    PlatformCapabilities capabilities = _android,
    DeviceMaker maker = const DeviceMaker(
      manufacturer: 'samsung',
      brand: 'samsung',
    ),
  }) => PhoneMakerSource(
    capabilities: capabilities,
    makerReader: FixedDeviceMakerReader(maker),
    os: os,
    store: store,
    guideRouteName: 'makerGuide',
  );

  setUp(() {
    store = _MemoryStore();
    os = const FixedOsVersionReader(15);
  });

  group('state rule', () {
    test('nothing marked needs a look and opens the guide', () {
      final check = PhoneMakerSource.phoneMakerCheckFor(
        record: MakerGuideRecord.none,
        osMajor: 15,
        guideRouteName: 'makerGuide',
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'maker_unchecked');
      expect(check.fix, const OpenRouteFix('makerGuide'));
      expect(check.id, ReliabilityCheckIds.phoneMaker);
    });

    test('marked done on this OS version is fine, with nothing to offer', () {
      final check = PhoneMakerSource.phoneMakerCheckFor(
        record: MakerGuideRecord(doneAt: _done, osMajor: 15),
        osMajor: 15,
        guideRouteName: 'makerGuide',
      );
      expect(check.state, ReliabilityState.fine);
      expect(check.fix, isNull);
      expect(check.reason, isNull);
      // The user's word is not a time the setting was known to work.
      expect(check.lastKnownGood, isNull);
    });

    test('a different OS version voids the word', () {
      final check = PhoneMakerSource.phoneMakerCheckFor(
        record: MakerGuideRecord(doneAt: _done, osMajor: 14),
        osMajor: 15,
        guideRouteName: 'makerGuide',
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'maker_os_changed');
      expect(check.fix, const OpenRouteFix('makerGuide'));
    });

    test('a phone that cannot say its version is compared as unknown', () {
      final same = PhoneMakerSource.phoneMakerCheckFor(
        record: MakerGuideRecord(doneAt: _done),
        osMajor: null,
        guideRouteName: 'makerGuide',
      );
      expect(same.state, ReliabilityState.fine);
      final later = PhoneMakerSource.phoneMakerCheckFor(
        record: MakerGuideRecord(doneAt: _done),
        osMajor: 15,
        guideRouteName: 'makerGuide',
      );
      expect(later.state, ReliabilityState.needsLook);
    });

    test('there is no way to be fine without the user marking it', () {
      for (final major in [null, 9, 15]) {
        final check = PhoneMakerSource.phoneMakerCheckFor(
          record: MakerGuideRecord.none,
          osMajor: major,
          guideRouteName: 'makerGuide',
        );
        expect(check.state, isNot(ReliabilityState.fine));
      }
    });
  });

  group('read', () {
    test('a listed maker with nothing marked needs a look', () async {
      final checks = await build().read();
      expect(checks.single.state, ReliabilityState.needsLook);
    });

    test(
      'a listed maker whose word was given on this version is fine',
      () async {
        store.record = MakerGuideRecord(doneAt: _done, osMajor: 15);
        expect((await build().read()).single.state, ReliabilityState.fine);
      },
    );

    test('a sub-brand counts: a Redmi on a Xiaomi manufacturer', () async {
      final checks = await build(
        maker: const DeviceMaker(manufacturer: 'Xiaomi', brand: 'Redmi'),
      ).read();
      expect(checks.single.state, ReliabilityState.needsLook);
    });

    test('a maker with no guide is not on this phone', () async {
      for (final name in ['google', 'motorola', 'vivo']) {
        final checks = await build(
          maker: DeviceMaker(manufacturer: name, brand: name),
        ).read();
        expect(
          checks.single.state,
          ReliabilityState.notOnThisPhone,
          reason: name,
        );
      }
    });

    test(
      'an iPhone is not on this phone, even with a listed maker name',
      () async {
        final checks = await build(
          capabilities: const PlatformCapabilities(
            isWeb: false,
            platform: TargetPlatform.iOS,
          ),
        ).read();
        expect(checks.single.state, ReliabilityState.notOnThisPhone);
      },
    );

    test('the web is not on this phone', () async {
      final checks = await build(
        capabilities: const PlatformCapabilities(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
      ).read();
      expect(checks.single.state, ReliabilityState.notOnThisPhone);
    });

    test('an unreadable maker is not on this phone', () async {
      final checks = await build(maker: DeviceMaker.unknown).read();
      expect(checks.single.state, ReliabilityState.notOnThisPhone);
    });
  });
}
