// Fixtures read best as plain statements on a draft.
// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart' show SeverityMode;
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/topics/domain/home_card/handled_window.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_rule.dart';
import 'package:critalarm/features/topics/domain/home_card/readiness_pips.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_card_fixtures.dart';

HomeCardModel resolve([void Function(Draft)? edit]) {
  final draft = Draft();
  edit?.call(draft);
  return resolveHomeCard(draft.build());
}

void main() {
  group('priority', () {
    test('lists every kind once', () {
      expect(homeCardPriority.toSet(), HomeCardKind.values.toSet());
      expect(homeCardPriority, hasLength(HomeCardKind.values.length));
    });

    test('ends with idle, which always holds', () {
      expect(homeCardPriority.last, HomeCardKind.idle);
      expect(resolve().kind, HomeCardKind.idle);
    });

    test('each fixture alone reaches its own kind', () {
      for (final kind in homeCardPriority) {
        expect(resolve(satisfy[kind]).kind, kind, reason: kind.name);
      }
    });

    test('when two adjacent kinds both hold, the earlier one wins', () {
      for (var i = 0; i < homeCardPriority.length - 1; i++) {
        final earlier = homeCardPriority[i];
        final later = homeCardPriority[i + 1];
        if (earlier == HomeCardKind.setup && later == HomeCardKind.waiting) {
          // Both read the one checklist, so they cannot hold together. The
          // next test covers the pair.
          continue;
        }
        final model = resolve((d) {
          satisfy[later]!(d);
          satisfy[earlier]!(d);
        });
        expect(
          model.kind,
          earlier,
          reason: '${earlier.name} over ${later.name}',
        );
      }
    });

    test(
      'setup and waiting never hold together: the first message decides',
      () {
        expect(
          resolve((d) => d.setup = setupAfterServer).kind,
          HomeCardKind.setup,
        );
        expect(
          resolve((d) => d.setup = setupFirstMessageOpen).kind,
          HomeCardKind.waiting,
        );
      },
    );

    test('each kind wins over every kind after it', () {
      final setupAt = homeCardPriority.indexOf(HomeCardKind.setup);
      for (var i = 0; i < homeCardPriority.length; i++) {
        final kind = homeCardPriority[i];
        final model = resolve((d) {
          for (final later in homeCardPriority.skip(i).toList().reversed) {
            // Waiting would replace the checklist that setup needs.
            if (later == HomeCardKind.waiting && i <= setupAt) continue;
            satisfy[later]!(d);
          }
        });
        expect(model.kind, kind, reason: kind.name);
      }
    });
  });

  group('the sixteen states', () {
    test('loading', () {
      final m = resolve(satisfy[HomeCardKind.loading]);
      expect(m.label, HomeCardLabel.willItWakeMe);
      expect(m.numeral, const Dots());
      expect(m.foot.slot, HomeCardFootSlot.askingServer);
      expect(m.action, isNull);
      expect(m.face, FaceState.calm);
      expect(m.severity, SeverityMode.none);
      expect(m.pips, isEmpty);
      expect(m.tapsReliability, isFalse);
    });

    test('ringing', () {
      final m = resolve(satisfy[HomeCardKind.ringing]);
      expect(m.label, HomeCardLabel.ringing);
      expect(
        m.numeral,
        Elapsed(now.subtract(const Duration(minutes: 2, seconds: 17))),
      );
      expect(
        m.foot,
        const HomeCardFoot(HomeCardFootSlot.topic, topic: 'prod-db'),
      );
      expect(m.action, const OpenAlarm('inc-ring'));
      expect(m.face, FaceState.alarmed);
      expect(m.severity, SeverityMode.crit);
      expect(m.numeralTone, HomeCardNumeralTone.redAlt);
    });

    test('ringing with no start time shows an unknown numeral', () {
      final m = resolve(
        (d) => d.ringing = const RingingFact(
          incidentId: 'x',
          topic: 'prod-db',
          openedAt: null,
        ),
      );
      expect(m.kind, HomeCardKind.ringing);
      expect(m.numeral, const Unknown());
    });

    test('acknowledged', () {
      final m = resolve(satisfy[HomeCardKind.acknowledged]);
      expect(m.label, HomeCardLabel.ringsAgainIn);
      expect(m.numeral, Remaining(now.add(const Duration(minutes: 9))));
      expect(
        m.foot,
        const HomeCardFoot(
          HomeCardFootSlot.topicUnlessClosed,
          topic: 'prod-db',
        ),
      );
      expect(m.action, const OpenIncident('inc-ack'));
      expect(m.face, FaceState.acked);
      expect(m.severity, SeverityMode.ack);
    });

    test('acknowledged ends when the desk timer runs out', () {
      final m = resolve(
        (d) => d.acknowledged = AcknowledgedFact(
          incidentId: 'x',
          topic: 'prod-db',
          deadline: now,
        ),
      );
      expect(m.kind, HomeCardKind.idle);
    });

    test('handled with the time to answer', () {
      final m = resolve(satisfy[HomeCardKind.handled]);
      expect(m.label, HomeCardLabel.answeredIn);
      expect(m.numeral, const Seconds(11));
      expect(m.foot.slot, HomeCardFootSlot.topicClosedAt);
      expect(m.foot.topic, 'prod-db');
      expect(m.foot.time, now.subtract(const Duration(seconds: 5)));
      expect(m.action, isNull);
      expect(m.face, FaceState.happy);
      expect(m.severity, SeverityMode.none);
    });

    test('handled without a known time to answer names the close time', () {
      final closedAt = now.subtract(const Duration(seconds: 5));
      final m = resolve(
        (d) => d.handled = HandledFact(topic: 'prod-db', closedAt: closedAt),
      );
      expect(m.kind, HomeCardKind.handled);
      expect(m.label, HomeCardLabel.closed);
      expect(m.numeral, At(closedAt));
      expect(m.foot.time, closedAt);
    });

    test('handled stops after the window', () {
      final m = resolve(
        (d) => d.handled = HandledFact(
          topic: 'prod-db',
          closedAt: now.subtract(handledCardWindow),
          answeredAfter: const Duration(seconds: 4),
        ),
      );
      expect(m.kind, HomeCardKind.idle);
    });

    test('missed', () {
      final m = resolve(satisfy[HomeCardKind.missed]);
      expect(m.label, HomeCardLabel.missed);
      expect(m.numeral, const Number(1));
      expect(m.foot.slot, HomeCardFootSlot.missedRang);
      expect(m.foot.duration, const Duration(minutes: 10));
      expect(m.foot.time, DateTime(2026, 10, 9, 3, 12));
      expect(m.action, const SeeMissed());
      expect(m.face, needsLookFace);
      expect(m.severity, SeverityMode.none);
      expect(m.numeralTone, HomeCardNumeralTone.red);
    });

    test('missed counts every alarm and works without a ring length', () {
      final m = resolve(
        (d) => d.missed = missedFact(count: 3, ringDuration: null),
      );
      expect(m.numeral, const Number(3));
      expect(m.foot.slot, HomeCardFootSlot.missedAt);
      expect(m.foot.duration, isNull);
    });

    test('no server', () {
      final m = resolve(satisfy[HomeCardKind.noServer]);
      expect(m.label, HomeCardLabel.none);
      expect(m.numeral, const No());
      expect(m.foot.slot, HomeCardFootSlot.noServer);
      expect(m.action, const ConnectServer());
      expect(m.face, FaceState.sad);
      expect(m.severity, SeverityMode.none);
    });

    test('stale', () {
      final m = resolve(satisfy[HomeCardKind.stale]);
      expect(m.label, HomeCardLabel.serverLastSeen);
      expect(m.numeral, At(DateTime(2026, 10, 8, 23, 10)));
      expect(m.foot.slot, HomeCardFootSlot.notAnswering);
      expect(m.action, const RetryLoad());
      expect(m.face, FaceState.watching);
      expect(m.numeralTone, HomeCardNumeralTone.muted);
    });

    test('load failed with no old copy', () {
      final m = resolve(satisfy[HomeCardKind.loadFailed]);
      expect(m.kind, HomeCardKind.loadFailed);
      expect(m.label, HomeCardLabel.server);
      expect(m.numeral, const Unknown());
      expect(m.foot.slot, HomeCardFootSlot.couldNotLoad);
      expect(m.action, const RetryLoad());
    });

    test('stale with no recorded time shows an unknown numeral', () {
      final m = resolve((d) => d.isStale = true);
      expect(m.kind, HomeCardKind.stale);
      expect(m.numeral, const Unknown());
    });

    test('no topics', () {
      final m = resolve(satisfy[HomeCardKind.noTopics]);
      expect(m.label, HomeCardLabel.topics);
      expect(m.numeral, const Number(0));
      expect(m.foot.slot, HomeCardFootSlot.nothingReachesYou);
      expect(m.action, isNull);
      expect(m.face, FaceState.interested);
    });

    test('warning', () {
      final m = resolve(satisfy[HomeCardKind.warning]);
      expect(m.label, HomeCardLabel.needsALook);
      expect(m.numeral, const Number(2));
      expect(m.foot.slot, HomeCardFootSlot.warningTopics);
      expect(m.action, isNull);
      expect(m.face, FaceState.worried);
      expect(m.severity, SeverityMode.high);
      expect(m.numeralTone, HomeCardNumeralTone.orangeAlt);
    });

    test('setup', () {
      final m = resolve(satisfy[HomeCardKind.setup]);
      expect(m.label, HomeCardLabel.setup);
      expect(m.numeral, const Count(1, 3));
      expect(m.pips, [PipTone.fine, PipTone.open, PipTone.open]);
      expect(
        m.foot,
        const HomeCardFoot(
          HomeCardFootSlot.setupNext,
          setupRow: SetupChecklistRow.criticalTopic,
        ),
      );
      expect(m.action, const ContinueSetup('/topics/prod-db'));
      expect(m.face, FaceState.calm);
    });

    test('setup with the first row open counts none done', () {
      final m = resolve(
        (d) => d.setup = const SetupChecklist(
          isVisible: true,
          hasServer: false,
          hasTopics: false,
          hasCriticalTopic: false,
          hasFirstMessage: false,
        ),
      );
      expect(m.kind, HomeCardKind.setup);
      expect(m.numeral, const Count(0, 3));
      expect(m.pips, [PipTone.open, PipTone.open, PipTone.open]);
      expect(m.foot.setupRow, SetupChecklistRow.server);
      expect(m.action, isNull);
    });

    test(
      'setup with no topic sends the critical row to the new topic page',
      () {
        final m = resolve((d) {
          d.setup = const SetupChecklist(
            isVisible: true,
            hasServer: true,
            hasTopics: false,
            hasCriticalTopic: false,
            hasFirstMessage: false,
          );
          d.firstTopic = null;
        });
        expect(m.kind, HomeCardKind.setup);
        expect(m.action, const ContinueSetup('/topics/new'));
      },
    );

    test('setup that is hidden or complete draws no setup card', () {
      expect(
        resolve((d) => d.setup = SetupChecklist.hidden).kind,
        HomeCardKind.idle,
      );
      expect(
        resolve(
          (d) => d.setup = const SetupChecklist(
            isVisible: true,
            hasServer: true,
            hasTopics: true,
            hasCriticalTopic: true,
            hasFirstMessage: true,
          ),
        ).kind,
        HomeCardKind.idle,
      );
    });

    test('waiting', () {
      final m = resolve(satisfy[HomeCardKind.waiting]);
      expect(m.label, HomeCardLabel.firstMessage);
      expect(m.numeral, const NotYet());
      expect(m.foot.slot, HomeCardFootSlot.sendTheLine);
      expect(m.action, const GetFirstLine('prod-db'));
      expect(m.face, FaceState.watching);
      expect(m.numeralTone, HomeCardNumeralTone.muted);
    });

    test('waiting with no watched topic has no action', () {
      final m = resolve((d) {
        d.setup = setupFirstMessageOpen;
        d.watchedTopic = null;
      });
      expect(m.kind, HomeCardKind.waiting);
      expect(m.action, isNull);
    });

    test('quiet', () {
      final m = resolve((d) {
        satisfy[HomeCardKind.quiet]!(d);
        d.lastAlarmAt = DateTime(2026, 9, 16, 4);
      });
      expect(m.label, HomeCardLabel.quietFor);
      expect(m.numeral, const Days(8));
      expect(
        m.foot,
        HomeCardFoot(
          HomeCardFootSlot.lastAlarm,
          time: DateTime(2026, 9, 16, 4),
        ),
      );
      expect(m.action, const SendTest());
      expect(m.face, FaceState.dozing);
      expect(m.severity, SeverityMode.none);
    });

    test('idle', () {
      final m = resolve();
      expect(m.label, HomeCardLabel.willItWakeMe);
      expect(m.numeral, const Count(7, 7));
      expect(m.pips, List.filled(7, PipTone.fine));
      expect(m.action, isNull);
      expect(m.face, FaceState.calm);
      expect(m.severity, SeverityMode.none);
      expect(m.tapsReliability, isTrue);
    });

    test('only idle and the issue kinds open the reliability screen', () {
      const opens = {
        HomeCardKind.idle,
        HomeCardKind.issueBroken,
        HomeCardKind.issueLook,
      };
      for (final kind in homeCardPriority) {
        final m = resolve(satisfy[kind]);
        expect(m.tapsReliability, opens.contains(kind), reason: kind.name);
      }
    });

    test('equal inputs give equal models', () {
      expect(
        resolve(satisfy[HomeCardKind.missed]),
        resolve(satisfy[HomeCardKind.missed]),
      );
      expect(
        resolve(satisfy[HomeCardKind.missed]),
        isNot(resolve(satisfy[HomeCardKind.warning])),
      );
    });
  });

  group('readiness', () {
    final phones = <String, List<List<ReliabilityCheck>>>{
      'Android': [androidChecks(7), androidChecks(8), androidChecks(9)],
      'iPhone': [iphoneChecks(6), iphoneChecks(7), iphoneChecks(8)],
    };

    for (final entry in phones.entries) {
      for (final checks in entry.value) {
        final n = checks.length;
        group('${entry.key} with $n checks', () {
          test('all fine is idle with n of n and n fine pips', () {
            final m = resolve((d) => d.checks = checks);
            expect(m.kind, HomeCardKind.idle);
            expect(m.numeral, Count(n, n));
            expect(m.pips, List.filled(n, PipTone.fine));
          });

          test('one needs a look is issueLook', () {
            const fix = OpenRouteFix('battery');
            final withLook = withCheckAt(
              checks,
              2,
              ReliabilityState.needsLook,
              reason: 'denied',
              fix: fix,
            );
            final m = resolve((d) => d.checks = withLook);
            expect(m.kind, HomeCardKind.issueLook);
            expect(m.numeral, Count(n - 1, n));
            expect(m.pips, hasLength(n));
            expect(m.pips[2], PipTone.look);
            expect(m.face, needsLookFace);
            expect(m.numeralTone, HomeCardNumeralTone.orange);
            expect(m.action, const Fix(fix));
            expect(
              m.foot,
              HomeCardFoot(
                HomeCardFootSlot.worstCheck,
                checkId: checks[2].id,
                reason: 'denied',
              ),
            );
          });

          test('one broken is issueBroken', () {
            const fix = OpenRouteFix('alarms');
            final withBroken = withCheckAt(
              checks,
              1,
              ReliabilityState.broken,
              reason: 'refused',
              fix: fix,
            );
            final m = resolve((d) => d.checks = withBroken);
            expect(m.kind, HomeCardKind.issueBroken);
            expect(m.numeral, Count(n - 1, n));
            expect(m.pips[1], PipTone.broken);
            expect(m.face, brokenFace);
            expect(m.numeralTone, HomeCardNumeralTone.redAlt);
            expect(m.action, const Fix(fix));
            expect(m.foot.checkId?.value, checks[1].id.value);
            expect(m.foot.reason, 'refused');
          });
        });
      }
    }

    test('not loaded gives dots and never a count', () {
      final m = resolve((d) => d.loaded = false);
      expect(m.kind, HomeCardKind.idle);
      expect(m.numeral, const Dots());
      expect(m.pips, isEmpty);
    });

    test('not loaded ignores checks that arrived early', () {
      final m = resolve((d) {
        d.loaded = false;
        d.checks = withCheckAt(androidChecks(7), 0, ReliabilityState.broken);
      });
      expect(m.kind, HomeCardKind.idle);
      expect(m.numeral, const Dots());
    });

    test('not loaded does not hide setup progress', () {
      final m = resolve((d) {
        d.loaded = false;
        d.setup = setupAfterServer;
      });
      expect(m.kind, HomeCardKind.setup);
      expect(m.numeral, const Count(1, 3));
    });

    test('incomplete is issueLook and the foot says a check could not run', () {
      final m = resolve((d) => d.incomplete = true);
      expect(m.kind, HomeCardKind.issueLook);
      expect(m.foot.slot, HomeCardFootSlot.checkCouldNotRun);
      expect(m.numeralTone, HomeCardNumeralTone.orange);
      expect(m.face, needsLookFace);
      expect(m.action, isNull);
    });

    test('incomplete with a broken check is still issueBroken', () {
      final m = resolve((d) {
        d.incomplete = true;
        d.checks = withCheckAt(androidChecks(7), 0, ReliabilityState.broken);
      });
      expect(m.kind, HomeCardKind.issueBroken);
      expect(m.foot.slot, HomeCardFootSlot.worstCheck);
    });

    test('a broken check beats one that needs a look, wherever it sits', () {
      final m = resolve((d) {
        d.checks = withCheckAt(
          withCheckAt(androidChecks(7), 0, ReliabilityState.needsLook),
          6,
          ReliabilityState.broken,
        );
      });
      expect(m.kind, HomeCardKind.issueBroken);
      expect(m.foot.checkId?.value, androidChecks(7)[6].id.value);
    });

    test('the action is the first fix, even when the worst check has none', () {
      const fix = OpenRouteFix('somewhere');
      final m = resolve((d) {
        d.checks = withCheckAt(
          withCheckAt(androidChecks(7), 0, ReliabilityState.broken),
          3,
          ReliabilityState.needsLook,
          fix: fix,
        );
      });
      expect(m.kind, HomeCardKind.issueBroken);
      expect(m.action, const Fix(fix));
    });

    test('a loaded read with no checks shows an unknown numeral', () {
      final m = resolve((d) => d.checks = const []);
      expect(m.kind, HomeCardKind.idle);
      expect(m.numeral, const Unknown());
    });
  });

  group('quiet', () {
    test('does not hold at 6 days 23 hours', () {
      final m = resolve(
        (d) => d.newestMessageAt = now.subtract(
          const Duration(days: 6, hours: 23),
        ),
      );
      expect(m.kind, HomeCardKind.idle);
    });

    test('holds at 7 days 1 hour', () {
      final m = resolve(
        (d) => d.newestMessageAt = now.subtract(
          const Duration(days: 7, hours: 1),
        ),
      );
      expect(m.kind, HomeCardKind.quiet);
      expect(m.numeral, const Days(7));
    });

    test('counts whole days', () {
      final m = resolve(
        (d) => d.newestMessageAt = now.subtract(
          const Duration(days: 23, hours: 20),
        ),
      );
      expect(m.numeral, const Days(23));
    });

    test('needs a message on record', () {
      expect(resolve((d) => d.newestMessageAt = null).kind, HomeCardKind.idle);
    });

    test('offers a test only with a critical topic', () {
      final withCritical = resolve((d) {
        satisfy[HomeCardKind.quiet]!(d);
        d.hasCriticalTopic = true;
      });
      final without = resolve((d) {
        satisfy[HomeCardKind.quiet]!(d);
        d.hasCriticalTopic = false;
      });
      expect(withCritical.action, const SendTest());
      expect(without.kind, HomeCardKind.quiet);
      expect(without.action, isNull);
    });

    test('foot says no alarm yet when none is on record', () {
      final m = resolve(satisfy[HomeCardKind.quiet]);
      expect(m.foot.slot, HomeCardFootSlot.noAlarmYet);
    });
  });

  group('idle foot', () {
    test('names the last alarm', () {
      final at = DateTime(2026, 10, 9, 0, 46);
      final m = resolve((d) => d.lastAlarmAt = at);
      expect(m.foot, HomeCardFoot(HomeCardFootSlot.lastAlarm, time: at));
    });

    test('says no alarm yet', () {
      final m = resolve();
      expect(m.foot.slot, HomeCardFootSlot.noAlarmYet);
    });

    test('says no topic rings when no topic has Critical delivery', () {
      final m = resolve((d) => d.hasCriticalTopic = false);
      expect(m.foot.slot, HomeCardFootSlot.noTopicRings);
    });

    test('says no topic rings even when an old alarm is on record', () {
      final m = resolve((d) {
        d.hasCriticalTopic = false;
        d.lastAlarmAt = DateTime(2026, 9, 1);
      });
      expect(m.foot.slot, HomeCardFootSlot.noTopicRings);
    });
  });
}
