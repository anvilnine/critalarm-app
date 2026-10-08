import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

const PaywallProduct _hosted = PaywallProduct.hosted;
const PaywallProduct _pro = PaywallProduct.pro;

/// What opens, as the door asks: the remote layout value is read for the
/// layout and for the intro it may still carry.
PaywallOpening? _open(
  PaywallProduct product,
  PaywallEntry entry, {
  String remote = '',
  String remoteIntro = '',
  PaywallLayoutSetting? developer,
  PaywallIntroId? developerIntro,
  bool hasSeenFalseAlarm = false,
}) => paywallOpeningFor(
  product: product,
  entry: entry,
  remote: PaywallLayoutSetting.parse(remote),
  developer: developer,
  remoteIntro: PaywallIntroId.parse(remoteIntro),
  developerIntro: developerIntro,
  legacyIntro: developer == null ? paywallIntroInLayoutValue(remote) : null,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
);

PaywallLayoutId? paywallLayoutFor({
  required PaywallProduct product,
  required PaywallEntry entry,
  required PaywallLayoutSetting remote,
  required bool hasSeenFalseAlarm,
}) => paywallOpeningFor(
  product: product,
  entry: entry,
  remote: remote,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.layout;

PaywallLayoutId? _hostedFrom(
  PaywallSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => _open(
  _hosted,
  paywallEntryOf(source),
  remote: remote,
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.layout;

PaywallLayoutId? _proFrom(
  ProPackSheetSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => _open(
  _pro,
  paywallEntryOfProSheet(source),
  remote: remote,
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.layout;

PaywallIntroId? _hostedIntroFrom(
  PaywallSource source, {
  String remote = '',
  String remoteIntro = '',
  PaywallLayoutSetting? developer,
  PaywallIntroId? developerIntro,
  bool hasSeenFalseAlarm = false,
}) => _open(
  _hosted,
  paywallEntryOf(source),
  remote: remote,
  remoteIntro: remoteIntro,
  developer: developer,
  developerIntro: developerIntro,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.intro;

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

  group('the false alarm intro', () {
    test('on auto it plays before hero on the Settings plan row, once', () {
      expect(
        _open(_hosted, PaywallEntry.settingsPlan, remote: 'auto'),
        const PaywallOpening(
          PaywallLayoutId.hero,
          intro: PaywallIntroId.falseAlarm,
        ),
      );
      expect(
        _open(
          _hosted,
          PaywallEntry.settingsPlan,
          remote: 'auto',
          hasSeenFalseAlarm: true,
        ),
        const PaywallOpening(PaywallLayoutId.hero),
      );
    });

    test('with no intro set it plays from no other entry point', () {
      for (final remote in ['auto', 'false_alarm']) {
        for (final source in PaywallSource.values) {
          if (source == PaywallSource.settingsPlan) continue;
          expect(
            _hostedIntroFrom(source, remote: remote),
            PaywallIntroId.none,
            reason: '$remote from $source',
          );
        }
      }
    });

    test('its old layout key reads as hero with the intro, same rule', () {
      expect(
        _open(_hosted, PaywallEntry.settingsPlan, remote: 'false_alarm'),
        const PaywallOpening(
          PaywallLayoutId.hero,
          intro: PaywallIntroId.falseAlarm,
        ),
      );
      expect(
        _open(
          _hosted,
          PaywallEntry.settingsPlan,
          remote: 'false_alarm',
          hasSeenFalseAlarm: true,
        ),
        const PaywallOpening(PaywallLayoutId.hero),
      );
      for (final source in PaywallSource.values) {
        expect(
          _hostedFrom(source, remote: 'false_alarm'),
          PaywallLayoutId.hero,
          reason: '$source',
        );
      }
    });

    test('with no intro set it never plays for Pro', () {
      for (final remote in ['auto', 'false_alarm']) {
        for (final entry in PaywallEntry.values) {
          expect(
            _open(_pro, entry, remote: remote)?.intro,
            PaywallIntroId.none,
          );
        }
      }
    });

    test('never plays at the defaults', () {
      expect(_hostedFrom(PaywallSource.settingsPlan), isNull);
      expect(
        _open(_hosted, PaywallEntry.settingsPlan, remoteIntro: 'false_alarm'),
        isNull,
      );
    });
  });

  group('the intro value', () {
    test('plays before any layout, from any entry, for both products', () {
      for (final product in PaywallProduct.values) {
        for (final entry in PaywallEntry.values) {
          for (final layout in ['hero', 'sheet', 'doors', 'auto']) {
            expect(
              _open(
                product,
                entry,
                remote: layout,
                remoteIntro: 'false_alarm',
              )?.intro,
              PaywallIntroId.falseAlarm,
              reason: '$product $entry $layout',
            );
          }
        }
      }
    });

    test('empty, and a value this build does not know, is no intro', () {
      for (final value in ['', '  ', 'falseAlarm', 'drumroll', 'none']) {
        expect(
          _hostedIntroFrom(
            PaywallSource.history,
            remote: 'hero',
            remoteIntro: value,
          ),
          PaywallIntroId.none,
          reason: value,
        );
      }
    });

    test('the false alarm still plays once on an install', () {
      expect(
        _hostedIntroFrom(
          PaywallSource.history,
          remote: 'sheet',
          remoteIntro: 'false_alarm',
          hasSeenFalseAlarm: true,
        ),
        PaywallIntroId.none,
      );
    });

    test('what Developer options set outranks the remote value', () {
      expect(
        _hostedIntroFrom(
          PaywallSource.history,
          remote: 'hero',
          developerIntro: PaywallIntroId.falseAlarm,
        ),
        PaywallIntroId.falseAlarm,
      );
      // No intro, set by hand, also beats the rule for the Settings row.
      expect(
        _hostedIntroFrom(
          PaywallSource.settingsPlan,
          remote: 'auto',
          remoteIntro: 'false_alarm',
          developerIntro: PaywallIntroId.none,
        ),
        PaywallIntroId.none,
      );
    });

    test('a developer layout drops the intro a remote layout carried', () {
      expect(
        _hostedIntroFrom(
          PaywallSource.settingsPlan,
          remote: 'false_alarm',
          developer: const PaywallLayoutSetting.pinned(PaywallLayoutId.sheet),
        ),
        PaywallIntroId.none,
      );
    });
  });
}
