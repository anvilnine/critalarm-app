import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

ReliabilityCheck check(
  String id,
  ReliabilityState state, {
  String? reason,
  ReliabilityFix? fix,
}) => ReliabilityCheck(
  id: ReliabilityCheckId(id),
  state: state,
  reason: reason,
  fix: fix,
);

void main() {
  group('orderReliabilityChecks', () {
    test('broken first, then needs a look, then fine', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.fine),
        check('b', ReliabilityState.needsLook),
        check('c', ReliabilityState.broken),
        check('d', ReliabilityState.fine),
      ]);

      expect(ordered.map((c) => c.id.value), ['c', 'b', 'a', 'd']);
    });

    test('keeps the source order inside one state', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.needsLook),
        check('b', ReliabilityState.broken),
        check('c', ReliabilityState.needsLook),
        check('d', ReliabilityState.broken),
        check('e', ReliabilityState.needsLook),
      ]);

      expect(ordered.map((c) => c.id.value), ['b', 'd', 'a', 'c', 'e']);
    });

    test('drops checks that are not on this phone', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.fine),
        const ReliabilityCheck.notOnThisPhone(ReliabilityCheckId('b')),
      ]);

      expect(ordered.map((c) => c.id.value), ['a']);
    });

    test('an empty list stays empty', () {
      expect(orderReliabilityChecks(const []), isEmpty);
    });
  });

  group('reliabilityLineKey', () {
    final cases = <String, String>{
      'refused': LocaleKeys.reliability_line_refused,
      'never': LocaleKeys.reliability_line_never,
      'stale': LocaleKeys.reliability_line_stale,
      'silent': LocaleKeys.reliability_line_silent,
      'time_sensitive_off': LocaleKeys.reliability_line_time_sensitive_off,
      'scheduled_summary': LocaleKeys.reliability_line_scheduled_summary,
      'os_changed': LocaleKeys.reliability_line_os_changed,
      'denied': LocaleKeys.reliability_line_denied,
      'restricted': LocaleKeys.reliability_line_restricted,
      'notDetermined': LocaleKeys.reliability_line_not_determined,
    };

    cases.forEach((reason, key) {
      test('$reason maps to its own line', () {
        expect(
          reliabilityLineKey(
            check('x', ReliabilityState.needsLook, reason: reason),
          ),
          key,
        );
      });
    });

    test('every status name a permission can give has a line', () {
      // The names of DevicePermissionStatus other than granted.
      for (final name in ['denied', 'restricted', 'notDetermined']) {
        expect(cases, contains(name));
      }
    });

    test('an unknown reason still gets a line for its state', () {
      expect(
        reliabilityLineKey(
          check('x', ReliabilityState.needsLook, reason: 'brand_new'),
        ),
        LocaleKeys.reliability_line_look_generic,
      );
      expect(
        reliabilityLineKey(
          check('x', ReliabilityState.broken, reason: 'brand_new'),
        ),
        LocaleKeys.reliability_line_broken_generic,
      );
    });

    test('no reason on a check that is not fine gets the generic line', () {
      expect(
        reliabilityLineKey(check('x', ReliabilityState.broken)),
        LocaleKeys.reliability_line_broken_generic,
      );
    });

    test('a fine check has no line, whatever its reason', () {
      expect(
        reliabilityLineKey(check('x', ReliabilityState.fine, reason: 'stale')),
        isNull,
      );
    });
  });

  group('reliabilityTitleKey', () {
    test('every id the sources use has a title', () {
      for (final id in [
        ReliabilityCheckIds.notifications,
        ReliabilityCheckIds.fullScreenAlarm,
        ReliabilityCheckIds.batteryOptimization,
        ReliabilityCheckIds.alarms,
        ReliabilityCheckIds.timeSensitive,
        ReliabilityCheckIds.pushTokenConfirmed,
        ReliabilityCheckIds.lastPushReceived,
        ReliabilityCheckIds.systemUpdate,
      ]) {
        expect(reliabilityTitleKey(id), isNotNull, reason: id.value);
      }
    });

    test('an unknown id has none, so the row shows the id', () {
      expect(reliabilityTitleKey(const ReliabilityCheckId('maker')), isNull);
    });
  });

  group('reliabilityFixLabelKey', () {
    test('picks the label by what the fix does', () {
      expect(
        reliabilityFixLabelKey(
          const OpenRouteFix('testRing'),
          testRouteName: 'testRing',
        ),
        LocaleKeys.reliability_fix_ring_test,
      );
      expect(
        reliabilityFixLabelKey(
          const OpenRouteFix('somewhere'),
          testRouteName: 'testRing',
        ),
        LocaleKeys.reliability_fix_open,
      );
      expect(
        reliabilityFixLabelKey(
          const RunFix(ReliabilityFixAction.reRegisterPushToken),
          testRouteName: 'testRing',
        ),
        LocaleKeys.reliability_fix_try_again,
      );
    });
  });

  group('isPermissionCheck', () {
    test('only the four permission rows open the permissions screen', () {
      expect(isPermissionCheck(ReliabilityCheckIds.notifications), isTrue);
      expect(isPermissionCheck(ReliabilityCheckIds.fullScreenAlarm), isTrue);
      expect(
        isPermissionCheck(ReliabilityCheckIds.batteryOptimization),
        isTrue,
      );
      expect(isPermissionCheck(ReliabilityCheckIds.alarms), isTrue);
      expect(isPermissionCheck(ReliabilityCheckIds.timeSensitive), isFalse);
      expect(isPermissionCheck(ReliabilityCheckIds.systemUpdate), isFalse);
    });
  });

  group('faces', () {
    test('two neighbours in one state never share a face', () {
      for (final state in [
        ReliabilityState.broken,
        ReliabilityState.needsLook,
        ReliabilityState.fine,
      ]) {
        for (var i = 0; i < 8; i++) {
          expect(
            reliabilityRowFace(state, i),
            isNot(reliabilityRowFace(state, i + 1)),
            reason: '${state.name} $i',
          );
        }
      }
    });

    test('a state does not borrow another state or the header face', () {
      final headerFaces = {
        for (final headline in ReliabilityHeadline.values)
          reliabilityHeadlineView(headline).face,
      };
      final seen = <FaceState, ReliabilityState>{};
      for (final state in [
        ReliabilityState.broken,
        ReliabilityState.needsLook,
        ReliabilityState.fine,
      ]) {
        for (var i = 0; i < 3; i++) {
          final face = reliabilityRowFace(state, i);
          expect(seen[face], anyOf(isNull, state), reason: face.name);
          seen[face] = state;
          expect(headerFaces, isNot(contains(face)), reason: face.name);
        }
      }
    });

    test('reliabilityRowFaces counts each state on its own', () {
      final faces = reliabilityRowFaces([
        check('a', ReliabilityState.broken),
        check('b', ReliabilityState.needsLook),
        check('c', ReliabilityState.needsLook),
        check('d', ReliabilityState.fine),
      ]);

      expect(faces, [
        reliabilityRowFace(ReliabilityState.broken, 0),
        reliabilityRowFace(ReliabilityState.needsLook, 0),
        reliabilityRowFace(ReliabilityState.needsLook, 1),
        reliabilityRowFace(ReliabilityState.fine, 0),
      ]);
    });
  });

  group('headline', () {
    test('is loading until the first read ends, whatever overall says', () {
      expect(
        reliabilityHeadline(const ReliabilitySnapshot()),
        ReliabilityHeadline.loading,
      );
    });

    test('follows the overall state once loaded', () {
      ReliabilityHeadline of(ReliabilityState overall) => reliabilityHeadline(
        ReliabilitySnapshot(overall: overall, loaded: true),
      );

      expect(of(ReliabilityState.fine), ReliabilityHeadline.fine);
      expect(of(ReliabilityState.needsLook), ReliabilityHeadline.needsLook);
      expect(of(ReliabilityState.broken), ReliabilityHeadline.broken);
    });

    test('each headline has its own face', () {
      final faces = {
        for (final headline in ReliabilityHeadline.values)
          reliabilityHeadlineView(headline).face,
      };

      expect(faces, hasLength(ReliabilityHeadline.values.length));
    });
  });

  test('reliabilityIssueCount counts what is not fine', () {
    expect(
      reliabilityIssueCount([
        check('a', ReliabilityState.fine),
        check('b', ReliabilityState.needsLook),
        check('c', ReliabilityState.broken),
      ]),
      2,
    );
  });
}
