import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/overall_state.dart';
import 'package:critalarm/features/reliability/domain/wake_answer.dart';
import 'package:flutter_test/flutter_test.dart';

ReliabilityCheck check(
  ReliabilityCheckId id,
  ReliabilityState state,
) => ReliabilityCheck(id: id, state: state);

const allIds = <ReliabilityCheckId>[
  ReliabilityCheckIds.notifications,
  ReliabilityCheckIds.fullScreenAlarm,
  ReliabilityCheckIds.alarms,
  ReliabilityCheckIds.batteryOptimization,
  ReliabilityCheckIds.timeSensitive,
  ReliabilityCheckIds.pushTokenConfirmed,
  ReliabilityCheckIds.lastPushReceived,
  ReliabilityCheckIds.systemUpdate,
  ReliabilityCheckIds.phoneMaker,
  ReliabilityCheckIds.missedAlarm,
];

void main() {
  group('wakeAnswerFor', () {
    test('an empty list is a yes', () {
      expect(wakeAnswerFor(const []), WakeAnswer.yes);
    });

    test('checks that are not on this phone are ignored', () {
      expect(
        wakeAnswerFor([
          const ReliabilityCheck.notOnThisPhone(ReliabilityCheckIds.alarms),
        ]),
        WakeAnswer.yes,
      );
    });

    test('agrees with overallReliabilityState for every combination', () {
      const states = ReliabilityState.values;
      var combinations = 0;
      for (final a in states) {
        for (final b in states) {
          for (final c in states) {
            final checks = [
              check(ReliabilityCheckIds.notifications, a),
              check(ReliabilityCheckIds.pushTokenConfirmed, b),
              check(ReliabilityCheckIds.missedAlarm, c),
            ];
            final expected = switch (overallReliabilityState(checks)) {
              ReliabilityState.broken => WakeAnswer.no,
              ReliabilityState.needsLook => WakeAnswer.maybe,
              _ => WakeAnswer.yes,
            };
            expect(wakeAnswerFor(checks), expected, reason: '$a $b $c');
            combinations++;
          }
        }
      }
      expect(combinations, 64);
    });

    test('broken beats needs a look', () {
      expect(
        wakeAnswerFor([
          check(
            ReliabilityCheckIds.batteryOptimization,
            ReliabilityState.needsLook,
          ),
          check(ReliabilityCheckIds.notifications, ReliabilityState.broken),
        ]),
        WakeAnswer.no,
      );
    });
  });

  group('wakeAnswerForSnapshot', () {
    test('an incomplete read is never a yes', () {
      expect(
        wakeAnswerForSnapshot(const [], incomplete: true),
        WakeAnswer.maybe,
      );
    });

    test('an incomplete read keeps a no', () {
      expect(
        wakeAnswerForSnapshot(
          [check(ReliabilityCheckIds.notifications, ReliabilityState.broken)],
          incomplete: true,
        ),
        WakeAnswer.no,
      );
    });

    test('a complete read is wakeAnswerFor', () {
      expect(
        wakeAnswerForSnapshot(const [], incomplete: false),
        WakeAnswer.yes,
      );
    });
  });

  group('wakeProblemCount and wakeWorstCheck', () {
    final checks = [
      check(ReliabilityCheckIds.notifications, ReliabilityState.fine),
      check(
        ReliabilityCheckIds.batteryOptimization,
        ReliabilityState.needsLook,
      ),
      check(ReliabilityCheckIds.fullScreenAlarm, ReliabilityState.broken),
      const ReliabilityCheck.notOnThisPhone(ReliabilityCheckIds.alarms),
      check(ReliabilityCheckIds.missedAlarm, ReliabilityState.needsLook),
    ];

    test('counts what is not fine', () {
      expect(wakeProblemCount(checks), 3);
      expect(wakeBrokenCount(checks), 1);
    });

    test('the worst check is the first in attention order', () {
      expect(wakeWorstCheck(checks)?.id, ReliabilityCheckIds.fullScreenAlarm);
    });

    test('among equals the sources order is kept', () {
      final looks = [
        check(ReliabilityCheckIds.missedAlarm, ReliabilityState.needsLook),
        check(
          ReliabilityCheckIds.batteryOptimization,
          ReliabilityState.needsLook,
        ),
      ];
      expect(wakeWorstCheck(looks)?.id, ReliabilityCheckIds.missedAlarm);
    });

    test('no worst check when every check passes', () {
      expect(wakeWorstCheck([checks.first]), isNull);
      expect(wakeWorstCheck(const []), isNull);
    });
  });

  group('wakePathFor', () {
    const expectedStop = <String, WakeStop>{
      'push_token_confirmed': WakeStop.server,
      'last_push_received': WakeStop.push,
      'time_sensitive': WakeStop.push,
      'notifications': WakeStop.phone,
      'full_screen_alarm': WakeStop.phone,
      'alarms': WakeStop.phone,
      'battery_optimization': WakeStop.phone,
      'phone_maker': WakeStop.phone,
      'system_update': WakeStop.phone,
      'missed_alarm': WakeStop.phone,
    };

    test('each of the ten ids lands on its stop', () {
      expect(allIds, hasLength(10));
      for (final id in allIds) {
        final path = wakePathFor([check(id, ReliabilityState.broken)]);
        final bad = wakeBadStops(path);
        expect(bad, hasLength(1), reason: id.value);
        expect(bad.single.stop, expectedStop[id.value], reason: id.value);
        expect(bad.single.problems, 1);
        expect(bad.single.state, ReliabilityState.broken);
      }
    });

    test('the stops come in path order', () {
      expect(
        [for (final s in wakePathFor(const [])) s.stop],
        [WakeStop.tool, WakeStop.server, WakeStop.push, WakeStop.phone],
      );
    });

    test('no problem leaves every stop fine', () {
      final path = wakePathFor([
        for (final id in allIds) check(id, ReliabilityState.fine),
      ]);
      expect(path.every((s) => s.isFine && s.problems == 0), isTrue);
    });

    test('two problems on one stop count twice and take the worse state', () {
      final path = wakePathFor([
        check(ReliabilityCheckIds.notifications, ReliabilityState.needsLook),
        check(ReliabilityCheckIds.fullScreenAlarm, ReliabilityState.broken),
        check(ReliabilityCheckIds.alarms, ReliabilityState.fine),
      ]);
      final phone = path.last;
      expect(phone.problems, 2);
      expect(phone.state, ReliabilityState.broken);
    });

    test('your tool is always fine', () {
      final path = wakePathFor([
        for (final id in allIds) check(id, ReliabilityState.broken),
      ]);
      expect(path.first.stop, WakeStop.tool);
      expect(path.first.isFine, isTrue);
    });

    test(
      'the weekly check sits on the push and an unknown id on the phone',
      () {
        expect(
          wakeStopOf(const ReliabilityCheckId('weekly_check')),
          WakeStop.push,
        );
        expect(
          wakeStopOf(const ReliabilityCheckId('brand_new')),
          WakeStop.phone,
        );
      },
    );

    test('a check that is not on this phone adds nothing', () {
      final path = wakePathFor([
        const ReliabilityCheck.notOnThisPhone(ReliabilityCheckIds.alarms),
      ]);
      expect(path.every((s) => s.isFine), isTrue);
    });
  });

  group('wakeLineFor', () {
    final now = DateTime(2026, 10, 9, 12);

    test('yes with a test names how long ago it rang', () {
      final line = wakeLineFor(
        const [],
        incomplete: false,
        now: now,
        lastTestAt: now.subtract(const Duration(hours: 2)),
      );
      expect(line.kind, WakeLineKind.testRang);
      expect(line.since, const Duration(hours: 2));
    });

    test('yes with no test nudges', () {
      expect(
        wakeLineFor(const [], incomplete: false, now: now).kind,
        WakeLineKind.noTestYet,
      );
    });

    test('a test from the future counts as just now', () {
      final line = wakeLineFor(
        const [],
        incomplete: false,
        now: now,
        lastTestAt: now.add(const Duration(hours: 1)),
      );
      expect(line.since, Duration.zero);
    });

    test('maybe names the worst check', () {
      final line = wakeLineFor(
        [
          check(
            ReliabilityCheckIds.batteryOptimization,
            ReliabilityState.needsLook,
          ),
        ],
        incomplete: false,
        now: now,
      );
      expect(line.kind, WakeLineKind.check);
      expect(line.checkId, ReliabilityCheckIds.batteryOptimization);
    });

    test('maybe from a source that failed says a check could not run', () {
      expect(
        wakeLineFor(const [], incomplete: true, now: now).kind,
        WakeLineKind.couldNotRun,
      );
    });

    test('no with several broken counts them', () {
      final line = wakeLineFor(
        [
          check(ReliabilityCheckIds.notifications, ReliabilityState.broken),
          check(ReliabilityCheckIds.fullScreenAlarm, ReliabilityState.broken),
          check(ReliabilityCheckIds.missedAlarm, ReliabilityState.needsLook),
        ],
        incomplete: false,
        now: now,
      );
      expect(line.kind, WakeLineKind.several);
      expect(line.count, 2);
    });

    test('no with one broken names it', () {
      final line = wakeLineFor(
        [
          check(ReliabilityCheckIds.notifications, ReliabilityState.broken),
          check(ReliabilityCheckIds.missedAlarm, ReliabilityState.needsLook),
        ],
        incomplete: false,
        now: now,
      );
      expect(line.kind, WakeLineKind.check);
      expect(line.checkId, ReliabilityCheckIds.notifications);
    });

    test('newestTestAt takes the latest time', () {
      final a = DateTime(2026, 10);
      final b = DateTime(2026, 10, 5);
      expect(newestTestAt([a, b, a]), b);
      expect(newestTestAt(const []), isNull);
    });
  });

  group('wakeAnswerSize', () {
    test('base sizes at 390 wide', () {
      expect(wakeAnswerSize(WakeAnswer.yes, 390, 1).fontSize, 76);
      expect(wakeAnswerSize(WakeAnswer.maybe, 390, 1).fontSize, 62);
      expect(wakeAnswerSize(WakeAnswer.no, 390, 1).fontSize, 68);
      expect(wakeAnswerSize(WakeAnswer.yes, 390, 1).faceSize, 124);
      expect(wakeAnswerSize(WakeAnswer.maybe, 390, 1).faceSize, 104);
    });

    test('never wider than its column and never meets the face', () {
      for (final word in WakeAnswer.values) {
        for (final width in [320.0, 360.0, 390.0, 430.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            final layout = wakeAnswerSize(word, width, scale);
            final reason = '${word.name} $width x$scale';
            final whole = width - 2 * wakeSideMargin;
            expect(
              layout.wordWidth,
              lessThanOrEqualTo(layout.columnWidth + 1e-9),
              reason: reason,
            );
            expect(
              layout.columnWidth,
              lessThanOrEqualTo(whole + 1e-9),
              reason: reason,
            );
            if (layout.isStacked) {
              // The face is under the word, so the word has the whole row.
              expect(layout.columnWidth, closeTo(whole, 1e-9), reason: reason);
            } else {
              expect(
                layout.wordWidth + wakeFaceGap + layout.faceSize,
                lessThanOrEqualTo(whole + 1e-9),
                reason: reason,
              );
            }
            expect(layout.fontSize, greaterThan(0), reason: reason);
          }
        }
      }
    });

    test('the word scales with the width', () {
      final narrow = wakeAnswerSize(WakeAnswer.no, 320, 1);
      final wide = wakeAnswerSize(WakeAnswer.no, 430, 1);
      expect(narrow.fontSize, lessThan(wide.fontSize));
    });

    test('large text stacks the face under the word', () {
      for (final word in WakeAnswer.values) {
        expect(wakeAnswerSize(word, 390, 2).isStacked, isTrue);
      }
    });

    test('the word stops growing with text past 1.3', () {
      expect(
        wakeAnswerSize(WakeAnswer.no, 390, 2).fontSize,
        wakeAnswerSize(WakeAnswer.no, 390, 1.3).fontSize,
      );
    });

    test('the ordinary phone keeps the face beside the word', () {
      for (final word in WakeAnswer.values) {
        expect(wakeAnswerSize(word, 390, 1).isStacked, isFalse);
      }
    });
  });

  group('wakePathDotAt', () {
    test('absent before 8% of the loop', () {
      expect(wakePathDotAt(0), isNull);
      expect(wakePathDotAt(wakeLoopSeconds * 0.07), isNull);
    });

    test('starts at the first stop at 8%', () {
      final dot = wakePathDotAt(wakeLoopSeconds * wakeDotStart)!;
      expect(dot.progress, closeTo(0, 1e-9));
      expect(dot.opacity, 1);
    });

    test('lands on the last stop at 70%', () {
      final dot = wakePathDotAt(wakeLoopSeconds * 0.7)!;
      expect(dot.progress, closeTo(1, 1e-9));
      expect(dot.opacity, 1);
    });

    test('moves forward through the trip', () {
      var last = -1.0;
      for (var u = 0.08; u <= 0.70; u += 0.02) {
        final progress = wakePathDotAt(wakeLoopSeconds * u)!.progress;
        expect(progress, greaterThanOrEqualTo(last));
        last = progress;
      }
    });

    test('fades after landing and is gone by 78%', () {
      final fading = wakePathDotAt(wakeLoopSeconds * 0.74)!;
      expect(fading.opacity, inExclusiveRange(0, 1));
      expect(wakePathDotAt(wakeLoopSeconds * 0.79), isNull);
    });

    test('repeats every loop', () {
      final a = wakePathDotAt(1.2)!;
      final b = wakePathDotAt(1.2 + wakeLoopSeconds * 3)!;
      expect(b.progress, closeTo(a.progress, 1e-9));
    });

    test('stalls at the stop that is not fine', () {
      for (final u in [0.4, 0.55, 0.7]) {
        final dot = wakePathDotAt(
          wakeLoopSeconds * u,
          brokenStop: WakeStop.push,
        )!;
        expect(dot.progress, lessThanOrEqualTo(2 / 3 + 1e-9));
      }
      final late = wakePathDotAt(
        wakeLoopSeconds * 0.7,
        brokenStop: WakeStop.push,
      )!;
      expect(late.progress, closeTo(2 / 3, 1e-9));
    });

    test('stalls at the server when the server is the one', () {
      final dot = wakePathDotAt(
        wakeLoopSeconds * 0.7,
        brokenStop: WakeStop.server,
      )!;
      expect(dot.progress, closeTo(1 / 3, 1e-9));
    });

    test('is absent when more than one stop is not fine', () {
      for (final u in [0.1, 0.4, 0.7]) {
        expect(
          wakePathDotAt(
            wakeLoopSeconds * u,
            brokenStop: WakeStop.server,
            brokenCount: 2,
          ),
          isNull,
        );
      }
    });
  });

  group('the other motion', () {
    test('the last stop swells as the dot lands and rests at 1', () {
      expect(wakeLandScaleAt(0), 1);
      expect(wakeLandScaleAt(wakeLoopSeconds * 0.5), 1);
      expect(wakeLandScaleAt(wakeLoopSeconds * 0.76), closeTo(1.18, 1e-9));
      expect(wakeLandScaleAt(wakeLoopSeconds * 0.86), closeTo(0.96, 1e-9));
      expect(wakeLandScaleAt(wakeLoopSeconds * 0.999), closeTo(1, 0.01));
    });

    test('the ring goes out and fades over its cycle', () {
      final start = wakePulseAt(0);
      final end = wakePulseAt(wakePulseSeconds * 0.99);
      expect(start.reach, 0);
      expect(start.strength, 1);
      expect(end.reach, closeTo(wakePulseReach, 0.1));
      expect(end.strength, closeTo(0, 0.02));
    });

    test('the disc breathes between 1 and a little more over 9 seconds', () {
      expect(wakeBreathSeconds, 9);
      expect(wakeBreathAt(0), closeTo(1, 1e-9));
      expect(wakeBreathAt(4.5), closeTo(1 + wakeBreathGrowth, 1e-9));
      expect(wakeBreathAt(9), closeTo(1, 1e-9));
    });
  });
}
