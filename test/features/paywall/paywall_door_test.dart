import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _Install {
  String hosted = '';
  String pro = '';
  PaywallLayoutSetting? devHosted;
  PaywallLayoutSetting? devPro;
  bool seen = false;
  int marks = 0;
  bool falseAlarmIsBuilt = true;
  bool remoteThrows = false;

  late final door = PaywallDoor(
    remoteValue: (product) {
      if (remoteThrows) throw StateError('no remote config');
      return product == PaywallProduct.hosted ? hosted : pro;
    },
    developer: (product) =>
        product == PaywallProduct.hosted ? devHosted : devPro,
    hasSeenFalseAlarm: () => seen,
    markFalseAlarmSeen: () async {
      seen = true;
      marks++;
    },
    isBuilt: (layout) =>
        layout != PaywallLayoutId.falseAlarm || falseAlarmIsBuilt,
  );
}

void main() {
  group('at the defaults', () {
    test('every Hosted entry opens the shipped paywall, as before', () {
      final install = _Install();
      for (final source in PaywallSource.values) {
        expect(
          install.door.hostedLocation(source),
          '/paywall?source=${source.wire}',
        );
        expect(
          install.door.resolve(paywallLocation(source)),
          paywallLocation(source),
        );
      }
      expect(install.door.resolve('/paywall'), '/paywall');
      expect(install.marks, 0);
    });

    test('every Pro entry opens the Pro sheet', () {
      final install = _Install();
      for (final source in ProPackSheetSource.values) {
        expect(install.door.proLayoutLocation(source), isNull);
      }
    });

    test('a layout location goes to the shipped surface in its place', () {
      final door = _Install().door;
      expect(door.opensLayouts(PaywallProduct.hosted), isFalse);
      expect(door.opensLayouts(PaywallProduct.pro), isFalse);
      expect(
        door.shippedInsteadOf(Uri.parse('/plans/hero?source=history')),
        '/paywall?source=history',
      );
      expect(
        door.shippedInsteadOf(Uri.parse('/plans/hero?product=hosted')),
        '/paywall?source=direct',
      );
      expect(
        door.shippedInsteadOf(
          Uri.parse('/plans/sheet?product=pro&source=reliability'),
        ),
        '/pro?source=reliability',
      );
    });

    test('with no door registered the helpers answer the same', () {
      expect(
        hostedPaywallLocation(PaywallSource.settingsPlan),
        '/paywall?source=settings_plan',
      );
      expect(
        resolvePaywallLocation('/paywall?source=history'),
        '/paywall?source=history',
      );
      expect(
        shippedPaywallInsteadOf(Uri.parse('/plans/hero?source=history')),
        '/paywall?source=history',
      );
      expect(
        shippedPaywallInsteadOf(Uri.parse('/plans/hero?product=pro')),
        '/pro',
      );
    });

    test('a remote read that throws opens the shipped surface', () {
      final install = _Install()..remoteThrows = true;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        isNull,
      );
      expect(
        install.door.shippedInsteadOf(Uri.parse('/plans/hero')),
        '/paywall?source=direct',
      );
    });

    test('an unknown remote value opens the shipped surface', () {
      final install = _Install()
        ..hosted = 'heroo'
        ..pro = 'yes';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        isNull,
      );
    });
  });

  group('with a remote value set', () {
    test('Hosted opens the layout with the product and the source', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/sheet?product=hosted&source=history',
      );
      expect(
        install.door.resolve('/paywall?source=reminder_pro_later'),
        '/plans/reel?product=hosted&source=reminder_pro_later',
      );
      expect(
        install.door.resolve('/paywall'),
        '/plans/hero?product=hosted&source=direct',
      );
      // Pro has its own value and still opens the sheet.
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        isNull,
      );
      expect(
        install.door.shippedInsteadOf(Uri.parse('/plans/sheet?source=history')),
        isNull,
      );
    });

    test('Pro opens the layout and keeps its own source word', () {
      final install = _Install()..pro = 'auto';
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/sheet?product=pro&source=reliability',
      );
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
    });

    test('a path that is not the paywall is left alone', () {
      final install = _Install()..hosted = 'auto';
      for (final path in ['/', '/ring', '/paywall/success', '/topics/a?x=1']) {
        expect(install.door.resolve(path), path);
      }
    });

    test('a layout never asks for the list of every benefit', () {
      final install = _Install()
        ..hosted = 'auto'
        ..pro = 'hero';
      expect(
        install.door.hostedLocation(PaywallSource.direct),
        isNot(contains('benefits')),
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        isNot(contains('benefits')),
      );
    });

    test('Developer options outrank it', () {
      final install = _Install()
        ..hosted = 'auto'
        ..devHosted = PaywallLayoutSetting.shipped
        ..devPro = const PaywallLayoutSetting.pinned(PaywallLayoutId.proof);
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/proof?product=pro&source=direct',
      );
    });
  });

  group('the False alarm layout', () {
    test('opens once from the Settings plan row, then hero', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/false_alarm?product=hosted&source=settings_plan',
      );
      expect(install.marks, 1);
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan',
      );
      expect(install.marks, 1);
    });

    test('other entries neither open it nor use up its showing', () {
      final install = _Install()..hosted = 'auto';
      for (final source in PaywallSource.values) {
        if (source == PaywallSource.settingsPlan) continue;
        expect(
          install.door.hostedLocation(source),
          isNot(contains('false_alarm')),
        );
      }
      expect(install.marks, 0);
    });

    test('a build that cannot draw it opens hero and keeps the showing', () {
      final install = _Install()
        ..hosted = 'auto'
        ..falseAlarmIsBuilt = false;
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan',
      );
      expect(install.marks, 0);
    });
  });
}
