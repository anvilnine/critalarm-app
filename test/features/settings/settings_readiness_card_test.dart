import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/readiness_pips.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/readiness_view.dart';
import 'package:critalarm/features/settings/presentation/settings_readiness_card.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_rule.dart';
import 'package:critalarm/features/topics/presentation/home_card_view.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../topics/domain/home_card/home_card_fixtures.dart' as fx;

ReliabilitySnapshot snapshot(
  List<ReliabilityCheck> checks, {
  bool loaded = true,
  bool incomplete = false,
}) => ReliabilitySnapshot(
  checks: checks,
  loaded: loaded,
  incomplete: incomplete,
);

void main() {
  group('SettingsReadinessView', () {
    test('says it is checking until the first read ends', () {
      final view = SettingsReadinessView.from(const ReliabilitySnapshot());

      expect(view.kind, ReadinessKind.loading);
      expect(view.summary.numeralText, '···');
      expect(view.summary.pips, isEmpty);
      expect(view.lineKey, LocaleKeys.reliability_loading);
      expect(view.face, FaceState.watching);
      expect(view.titleNamesCheck, isFalse);
      expect(view.fix, isNull);
    });

    test('all fine: a happy face, the full count, no fix', () {
      final view = SettingsReadinessView.from(snapshot(fx.androidChecks(7)));

      expect(view.kind, ReadinessKind.fine);
      expect(view.face, FaceState.happy);
      expect(view.summary.numeralText, '7/7');
      expect(view.summary.pips, List.filled(7, PipTone.fine));
      expect(view.lineKey, LocaleKeys.reliability_overall_fine_line);
      expect(view.titleNamesCheck, isFalse);
      expect(view.titleCheck, isNull);
      expect(view.fix, isNull);
    });

    test('a check that needs a look: skeptical, names it, offers its fix', () {
      const fix = OpenRouteFix('battery');
      final view = SettingsReadinessView.from(
        snapshot(
          fx.withCheckAt(
            fx.androidChecks(7),
            2,
            ReliabilityState.needsLook,
            reason: 'denied',
            fix: fix,
          ),
        ),
      );

      expect(view.kind, ReadinessKind.look);
      expect(view.face, FaceState.skeptical);
      expect(view.summary.numeralText, '6/7');
      expect(view.titleCheck, ReliabilityCheckIds.batteryOptimization);
      expect(view.titleNamesCheck, isTrue);
      expect(view.fix, fix);
    });

    test('a broken check beats one that needs a look', () {
      const fix = OpenRouteFix('alarms');
      final checks = fx.withCheckAt(
        fx.withCheckAt(
          fx.androidChecks(7),
          2,
          ReliabilityState.needsLook,
        ),
        1,
        ReliabilityState.broken,
        fix: fix,
      );
      final view = SettingsReadinessView.from(snapshot(checks));

      expect(view.kind, ReadinessKind.broken);
      expect(view.face, FaceState.sad);
      expect(view.summary.numeralText, '5/7');
      expect(view.titleCheck, ReliabilityCheckIds.fullScreenAlarm);
      expect(view.fix, fix);
    });

    test('a read with a hole in it is never fine', () {
      final view = SettingsReadinessView.from(
        snapshot(fx.androidChecks(6), incomplete: true),
      );

      expect(view.kind, ReadinessKind.look);
      expect(view.titleIsMissingCheck, isTrue);
      expect(view.fix, isNull);
    });

    test('a loaded phone with no checks shows a question mark', () {
      final view = SettingsReadinessView.from(snapshot(const []));

      expect(view.kind, ReadinessKind.fine);
      expect(view.summary.numeralText, '?');
    });
  });

  group('sentenceCase', () {
    test('lifts the first letter and leaves the rest', () {
      expect(sentenceCase('battery saver is on'), 'Battery saver is on');
      expect(sentenceCase(''), '');
    });
  });

  // The Topics card and the Settings card read one rule. Every case below is
  // read by both and has to say the same thing.
  group('Topics card and Settings card agree', () {
    const lookFix = OpenRouteFix('battery');
    const brokenFix = OpenRouteFix('alarms');
    final cases = <String, ReliabilitySnapshot>{
      'before the first read': snapshot(
        fx.androidChecks(7),
        loaded: false,
      ),
      'all fine, 7 checks': snapshot(fx.androidChecks(7)),
      'all fine, 9 checks': snapshot(fx.androidChecks(9)),
      'iphone checks': snapshot(fx.iphoneChecks(6)),
      'no checks': snapshot(const []),
      'one needs a look': snapshot(
        fx.withCheckAt(
          fx.androidChecks(7),
          2,
          ReliabilityState.needsLook,
          reason: 'denied',
          fix: lookFix,
        ),
      ),
      'one broken': snapshot(
        fx.withCheckAt(
          fx.androidChecks(7),
          1,
          ReliabilityState.broken,
          reason: 'refused',
          fix: brokenFix,
        ),
      ),
      'look and broken together': snapshot(
        fx.withCheckAt(
          fx.withCheckAt(
            fx.androidChecks(8),
            4,
            ReliabilityState.needsLook,
            fix: lookFix,
          ),
          6,
          ReliabilityState.broken,
          fix: brokenFix,
        ),
      ),
      'a look with no fix': snapshot(
        fx.withCheckAt(fx.androidChecks(7), 3, ReliabilityState.needsLook),
      ),
      'incomplete read': snapshot(fx.androidChecks(6), incomplete: true),
      'incomplete read with a look': snapshot(
        fx.withCheckAt(
          fx.androidChecks(6),
          0,
          ReliabilityState.needsLook,
          fix: lookFix,
        ),
        incomplete: true,
      ),
      'incomplete read with a broken check': snapshot(
        fx.withCheckAt(
          fx.androidChecks(6),
          0,
          ReliabilityState.broken,
          fix: brokenFix,
        ),
        incomplete: true,
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final snap = entry.value;
        final home = homeCardViewFor(
          resolveHomeCard(
            (fx.Draft()
                  ..loaded = snap.loaded
                  ..incomplete = snap.incomplete
                  ..checks = snap.checks)
                .build(),
          ),
          now: fx.now,
        );
        final model = resolveHomeCard(
          (fx.Draft()
                ..loaded = snap.loaded
                ..incomplete = snap.incomplete
                ..checks = snap.checks)
              .build(),
        );
        final settings = SettingsReadinessView.from(snap);

        // Same kind of card, with nothing else in the way.
        expect(
          model.kind,
          switch (settings.kind) {
            ReadinessKind.loading || ReadinessKind.fine => HomeCardKind.idle,
            ReadinessKind.look => HomeCardKind.issueLook,
            ReadinessKind.broken => HomeCardKind.issueBroken,
          },
        );
        // The numeral, the pips and the numeral colour.
        expect(settings.summary.numeralText, home.numeral);
        expect(
          [for (final p in settings.summary.pips) readinessPipTone(p)],
          home.pips ?? <AppPipTone>[],
        );
        if (settings.kind != ReadinessKind.loading) {
          expect(readinessNumeralTone(settings.kind), home.numeralTone);
        }
        // The check the card names.
        if (model.kind == HomeCardKind.issueLook ||
            model.kind == HomeCardKind.issueBroken) {
          final line = settings.titleIsMissingCheck
              ? 'a check could not run'
              : readinessCheckLine(settings.titleCheck);
          expect(line, home.foot);
        }
        // The button: the same fix, or none.
        final action = model.action;
        expect(action is Fix ? action.fix : null, settings.fix);
        expect(home.actionLabel != null, settings.fix != null);
      });
    }
  });
}
