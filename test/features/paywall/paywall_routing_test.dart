import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

const PaywallProduct _hosted = PaywallProduct.hosted;
const PaywallProduct _pro = PaywallProduct.pro;

PaywallLayoutId? _hostedFrom(
  PaywallSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => paywallLayoutFor(
  product: _hosted,
  entry: paywallEntryOf(source),
  remote: PaywallLayoutSetting.parse(remote),
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
);

PaywallLayoutId? _proFrom(
  ProPackSheetSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => paywallLayoutFor(
  product: _pro,
  entry: paywallEntryOfProSheet(source),
  remote: PaywallLayoutSetting.parse(remote),
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
);

void main() {
  group('entry points', () {
    test('every Hosted source has its row', () {
      const expected = <PaywallSource, PaywallEntry>{
        PaywallSource.createTopicCard: PaywallEntry.capHit,
        PaywallSource.historyOlder: PaywallEntry.capHit,
        PaywallSource.history: PaywallEntry.capHit,
        PaywallSource.widgetLocked: PaywallEntry.lockedRow,
        PaywallSource.homeWidgets: PaywallEntry.lockedRow,
        PaywallSource.appIcon: PaywallEntry.lockedRow,
        PaywallSource.settingsPlan: PaywallEntry.settingsPlan,
        PaywallSource.settingsSearch: PaywallEntry.settingsSearch,
        PaywallSource.askSheet: PaywallEntry.nudge,
        PaywallSource.homeDay0Card: PaywallEntry.nudge,
        PaywallSource.reminderMorningAfter: PaywallEntry.nudge,
        PaywallSource.reminderProLater: PaywallEntry.nudge,
        PaywallSource.planSheetEnding: PaywallEntry.lapse,
        PaywallSource.planSheetEnded: PaywallEntry.lapse,
        PaywallSource.direct: PaywallEntry.other,
      };
      for (final source in PaywallSource.values) {
        expect(paywallEntryOf(source), expected[source], reason: '$source');
      }
    });

    test('every Pro source has its row', () {
      expect(
        paywallEntryOfProSheet(ProPackSheetSource.reliability),
        PaywallEntry.lockedRow,
      );
      expect(
        paywallEntryOfProSheet(ProPackSheetSource.direct),
        PaywallEntry.other,
      );
    });
  });

  group('at the defaults nothing changes', () {
    test('an empty value opens the shipped surface from every entry', () {
      for (final seen in [false, true]) {
        for (final source in PaywallSource.values) {
          expect(
            _hostedFrom(source, hasSeenFalseAlarm: seen),
            isNull,
            reason: '$source',
          );
        }
        for (final source in ProPackSheetSource.values) {
          expect(
            _proFrom(source, hasSeenFalseAlarm: seen),
            isNull,
            reason: '$source',
          );
        }
        for (final product in PaywallProduct.values) {
          for (final entry in PaywallEntry.values) {
            expect(
              paywallLayoutFor(
                product: product,
                entry: entry,
                remote: PaywallLayoutSetting.shipped,
                hasSeenFalseAlarm: seen,
              ),
              isNull,
              reason: '$product $entry',
            );
          }
        }
      }
    });

    test('a value this build does not know opens the shipped surface', () {
      for (final typo in ['heroo', 'AUTO', 'yes', 'true', 'shipped']) {
        for (final source in PaywallSource.values) {
          expect(_hostedFrom(source, remote: typo), isNull, reason: typo);
        }
        for (final source in ProPackSheetSource.values) {
          expect(_proFrom(source, remote: typo), isNull, reason: typo);
        }
      }
    });
  });

  group('auto', () {
    test('Hosted picks by entry point', () {
      // The False alarm layout has had its showing, so the Settings plan
      // row reads as the table has it.
      const expected = <PaywallSource, PaywallLayoutId>{
        PaywallSource.createTopicCard: PaywallLayoutId.sheet,
        PaywallSource.historyOlder: PaywallLayoutId.sheet,
        PaywallSource.history: PaywallLayoutId.sheet,
        PaywallSource.widgetLocked: PaywallLayoutId.sheet,
        PaywallSource.homeWidgets: PaywallLayoutId.sheet,
        PaywallSource.appIcon: PaywallLayoutId.sheet,
        PaywallSource.settingsPlan: PaywallLayoutId.hero,
        PaywallSource.settingsSearch: PaywallLayoutId.hero,
        PaywallSource.askSheet: PaywallLayoutId.reel,
        PaywallSource.homeDay0Card: PaywallLayoutId.reel,
        PaywallSource.reminderMorningAfter: PaywallLayoutId.reel,
        PaywallSource.reminderProLater: PaywallLayoutId.reel,
        PaywallSource.planSheetEnding: PaywallLayoutId.doors,
        PaywallSource.planSheetEnded: PaywallLayoutId.doors,
        PaywallSource.direct: PaywallLayoutId.hero,
      };
      for (final source in PaywallSource.values) {
        expect(
          _hostedFrom(source, remote: 'auto', hasSeenFalseAlarm: true),
          expected[source],
          reason: '$source',
        );
      }
    });

    test('Pro picks by entry point', () {
      PaywallLayoutId? from(PaywallEntry entry) => paywallLayoutFor(
        product: _pro,
        entry: entry,
        remote: PaywallLayoutSetting.auto,
        hasSeenFalseAlarm: false,
      );
      expect(
        _proFrom(ProPackSheetSource.reliability, remote: 'auto'),
        PaywallLayoutId.sheet,
      );
      expect(
        _proFrom(ProPackSheetSource.direct, remote: 'auto'),
        PaywallLayoutId.hero,
      );
      expect(from(PaywallEntry.lockedRow), PaywallLayoutId.sheet);
      expect(from(PaywallEntry.settingsPlan), PaywallLayoutId.hero);
      expect(from(PaywallEntry.settingsSearch), PaywallLayoutId.hero);
      expect(from(PaywallEntry.nudge), PaywallLayoutId.reel);
      expect(from(PaywallEntry.other), PaywallLayoutId.hero);
    });

    test('one product on auto leaves the other alone', () {
      expect(_hostedFrom(PaywallSource.direct, remote: 'auto'), isNotNull);
      expect(_proFrom(ProPackSheetSource.direct), isNull);
    });
  });

  group('a named layout', () {
    test('opens from every entry point, for both products', () {
      for (final layout in PaywallLayoutId.values) {
        if (layout == PaywallLayoutId.falseAlarm) continue;
        for (final source in PaywallSource.values) {
          expect(_hostedFrom(source, remote: layout.key), layout);
        }
        for (final source in ProPackSheetSource.values) {
          expect(_proFrom(source, remote: layout.key), layout);
        }
      }
    });

    test('hero by name stays hero on the Settings plan row', () {
      expect(
        _hostedFrom(PaywallSource.settingsPlan, remote: 'hero'),
        PaywallLayoutId.hero,
      );
    });
  });

  group('the developer control', () {
    test('outranks the remote value', () {
      expect(
        _hostedFrom(
          PaywallSource.history,
          remote: 'hero',
          developer: PaywallLayoutSetting.auto,
        ),
        PaywallLayoutId.sheet,
      );
      expect(
        _proFrom(
          ProPackSheetSource.reliability,
          developer: const PaywallLayoutSetting.pinned(PaywallLayoutId.proof),
        ),
        PaywallLayoutId.proof,
      );
    });

    test('shipped opens the shipped surface whatever remote says', () {
      for (final remote in ['auto', 'hero', 'sheet']) {
        expect(
          _hostedFrom(
            PaywallSource.settingsPlan,
            remote: remote,
            developer: PaywallLayoutSetting.shipped,
          ),
          isNull,
        );
        expect(
          _proFrom(
            ProPackSheetSource.reliability,
            remote: remote,
            developer: PaywallLayoutSetting.shipped,
          ),
          isNull,
        );
      }
    });

    test('following remote is the remote value', () {
      expect(_hostedFrom(PaywallSource.askSheet), isNull);
      expect(
        _hostedFrom(PaywallSource.askSheet, remote: 'auto'),
        PaywallLayoutId.reel,
      );
    });
  });

  group('the False alarm layout', () {
    test('takes the place of hero on the Settings plan row, once', () {
      expect(
        _hostedFrom(PaywallSource.settingsPlan, remote: 'auto'),
        PaywallLayoutId.falseAlarm,
      );
      expect(
        _hostedFrom(
          PaywallSource.settingsPlan,
          remote: 'auto',
          hasSeenFalseAlarm: true,
        ),
        PaywallLayoutId.hero,
      );
    });

    test('never opens from any other entry point', () {
      for (final remote in ['auto', 'false_alarm']) {
        for (final source in PaywallSource.values) {
          if (source == PaywallSource.settingsPlan) continue;
          expect(
            _hostedFrom(source, remote: remote),
            isNot(PaywallLayoutId.falseAlarm),
            reason: '$remote from $source',
          );
        }
      }
    });

    test('by name it keeps the same rule and falls back to hero', () {
      expect(
        _hostedFrom(PaywallSource.settingsPlan, remote: 'false_alarm'),
        PaywallLayoutId.falseAlarm,
      );
      expect(
        _hostedFrom(
          PaywallSource.settingsPlan,
          remote: 'false_alarm',
          hasSeenFalseAlarm: true,
        ),
        PaywallLayoutId.hero,
      );
      for (final source in [
        PaywallSource.createTopicCard,
        PaywallSource.history,
        PaywallSource.planSheetEnding,
        PaywallSource.planSheetEnded,
        PaywallSource.reminderMorningAfter,
        PaywallSource.reminderProLater,
        PaywallSource.askSheet,
        PaywallSource.homeDay0Card,
      ]) {
        expect(
          _hostedFrom(source, remote: 'false_alarm'),
          PaywallLayoutId.hero,
          reason: '$source',
        );
      }
    });

    test('never opens for Pro', () {
      for (final remote in ['auto', 'false_alarm']) {
        for (final entry in PaywallEntry.values) {
          expect(
            paywallLayoutFor(
              product: _pro,
              entry: entry,
              remote: PaywallLayoutSetting.parse(remote),
              hasSeenFalseAlarm: false,
            ),
            isNot(PaywallLayoutId.falseAlarm),
          );
        }
      }
    });

    test('never opens at the defaults', () {
      expect(_hostedFrom(PaywallSource.settingsPlan), isNull);
    });
  });
}
