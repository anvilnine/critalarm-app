import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/sources/last_push_source.dart';
import 'package:critalarm/features/reliability/domain/sources/permissions_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_translations.dart';

ReliabilityCheck check(
  String id,
  ReliabilityState state, {
  String? reason,
  ReliabilityFix? fix,
  DateTime? lastKnownGood,
}) => ReliabilityCheck(
  id: ReliabilityCheckId(id),
  state: state,
  reason: reason,
  fix: fix,
  lastKnownGood: lastKnownGood,
);

/// Every id a source in this feature gives.
const sourceIds = <ReliabilityCheckId>[
  ReliabilityCheckIds.notifications,
  ReliabilityCheckIds.fullScreenAlarm,
  ReliabilityCheckIds.batteryOptimization,
  ReliabilityCheckIds.alarms,
  ReliabilityCheckIds.timeSensitive,
  ReliabilityCheckIds.pushTokenConfirmed,
  ReliabilityCheckIds.lastPushReceived,
  ReliabilityCheckIds.systemUpdate,
  ReliabilityCheckIds.phoneMaker,
  ReliabilityCheckIds.missedAlarm,
];

/// A check from a source this feature does not know, such as a later one.
const laterId = 'a_later_source';

void main() {
  // `reliabilityAgo` reads its unit words from the strings.
  setUpAll(loadTestTranslations);

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
      'clock': LocaleKeys.reliability_line_clock,
      'time_sensitive_off': LocaleKeys.reliability_line_time_sensitive_off,
      'scheduled_summary': LocaleKeys.reliability_line_scheduled_summary,
      'os_changed': LocaleKeys.reliability_line_os_changed,
      'denied': LocaleKeys.reliability_line_denied,
      'restricted': LocaleKeys.reliability_line_restricted,
      'notDetermined': LocaleKeys.reliability_line_not_determined,
    };

    for (final MapEntry(key: reason, value: key) in cases.entries) {
      test('$reason maps to its own line', () {
        expect(
          reliabilityLineKey(
            check('x', ReliabilityState.needsLook, reason: reason),
          ),
          key,
        );
      });
    }

    test('a denied permission names what it costs, by check', () {
      final expected = {
        ReliabilityCheckIds.notifications:
            LocaleKeys.reliability_line_denied_notifications,
        ReliabilityCheckIds.fullScreenAlarm:
            LocaleKeys.reliability_line_denied_full_screen,
        ReliabilityCheckIds.batteryOptimization:
            LocaleKeys.reliability_line_denied_battery,
        ReliabilityCheckIds.alarms: LocaleKeys.reliability_line_denied_alarms,
      };
      for (final MapEntry(key: id, value: key) in expected.entries) {
        expect(
          reliabilityLineKey(
            check(id.value, ReliabilityState.broken, reason: 'denied'),
          ),
          key,
          reason: id.value,
        );
      }
    });

    test('a denied check this screen does not know keeps the shared line', () {
      expect(
        reliabilityLineKey(
          check('brand_new', ReliabilityState.broken, reason: 'denied'),
        ),
        LocaleKeys.reliability_line_denied,
      );
    });

    test('every status name a permission can give has a line', () {
      for (final status in DevicePermissionStatus.values) {
        if (status.isGranted) continue;
        expect(cases, contains(status.name));
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

    test('a later source sorts by its state like any other', () {
      final ordered = orderReliabilityChecks([
        check('notifications', ReliabilityState.fine),
        check(laterId, ReliabilityState.needsLook),
        check('missed_alarm', ReliabilityState.fine),
      ]);
      expect(ordered.first.id.value, laterId);
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

    test('a permission asked for in the app reads "Allow"', () {
      expect(
        reliabilityFixLabelKey(
          const AskPermissionFix(DevicePermissionType.notifications),
          testRouteName: 'testRing',
        ),
        LocaleKeys.reliability_fix_allow,
      );
    });

    test('a permission that was never asked for reads "Allow"', () {
      final notAsked = PermissionsSource.permissionCheckFor(
        DevicePermissionType.notifications,
        DevicePermissionStatus.notDetermined,
      );
      expect(
        reliabilityFixLabelKey(notAsked.fix!, testRouteName: 'testRing'),
        LocaleKeys.reliability_fix_allow,
      );
      final denied = PermissionsSource.permissionCheckFor(
        DevicePermissionType.notifications,
        DevicePermissionStatus.denied,
      );
      expect(
        reliabilityFixLabelKey(denied.fix!, testRouteName: 'testRing'),
        LocaleKeys.reliability_fix_open_settings,
      );
    });
  });

  group('reliabilityRowTitleKey', () {
    test('a fine check that reads wrong beside a tick says what it means', () {
      expect(
        reliabilityRowTitleKey(check('missed_alarm', ReliabilityState.fine)),
        LocaleKeys.reliability_check_missed_alarm_fine,
      );
      expect(
        reliabilityRowTitleKey(check('system_update', ReliabilityState.fine)),
        LocaleKeys.reliability_check_system_update_fine,
      );
    });

    test('the same checks keep their plain name when not fine', () {
      expect(
        reliabilityRowTitleKey(
          check('missed_alarm', ReliabilityState.needsLook),
        ),
        LocaleKeys.reliability_check_missed_alarm,
      );
      expect(
        reliabilityRowTitleKey(
          check('system_update', ReliabilityState.needsLook),
        ),
        LocaleKeys.reliability_check_system_update,
      );
    });

    test('every other check has one title in every state', () {
      for (final id in sourceIds) {
        if (id == ReliabilityCheckIds.missedAlarm ||
            id == ReliabilityCheckIds.systemUpdate) {
          continue;
        }
        for (final state in ReliabilityState.values) {
          expect(
            reliabilityRowTitleKey(check(id.value, state)),
            reliabilityTitleKey(id),
            reason: '${id.value} ${state.name}',
          );
        }
      }
    });

    test('an unknown id has none, so the row shows the id', () {
      expect(
        reliabilityRowTitleKey(check(laterId, ReliabilityState.fine)),
        isNull,
      );
    });
  });

  group('reliabilityFineValue', () {
    final now = DateTime.utc(2026, 10, 7, 12);

    ReliabilityCheck lastPush({
      DateTime? at,
      bool hasCriticalTopic = true,
      DateTime? watchingSince,
    }) => LastPushSource.lastPushCheckFor(
      now: now,
      lastPushAt: at,
      watchingSince: watchingSince ?? now.subtract(const Duration(days: 1)),
      hasCriticalTopic: hasCriticalTopic,
      testRouteName: 'testRing',
    );

    test('a push two hours ago shows the time in place of the tick', () {
      final value = reliabilityFineValue(
        lastPush(at: now.subtract(const Duration(hours: 2, minutes: 40))),
        now: now,
      )!;
      expect(value.key, LocaleKeys.reliability_last_push_ago);
      expect(value.args, {'when': '2 h'});
    });

    test('a phone that never received a push says none yet', () {
      for (final hasCriticalTopic in [true, false]) {
        final check = lastPush(hasCriticalTopic: hasCriticalTopic);
        expect(check.state, ReliabilityState.fine);
        final value = reliabilityFineValue(check, now: now)!;
        expect(value.key, LocaleKeys.reliability_last_push_none);
        expect(value.args, isEmpty);
      }
    });

    test('with no critical topic the time still shows', () {
      final value = reliabilityFineValue(
        lastPush(
          at: now.subtract(const Duration(days: 20)),
          hasCriticalTopic: false,
        ),
        now: now,
      )!;
      expect(value.args, {'when': '20 d'});
    });

    test('a push dated after now keeps the tick', () {
      expect(
        reliabilityFineValue(
          lastPush(
            at: now.add(const Duration(hours: 3)),
            hasCriticalTopic: false,
          ),
          now: now,
        ),
        isNull,
      );
    });

    test('a row that needs a look has no value', () {
      final silent = lastPush(at: now.subtract(const Duration(days: 12)));
      expect(silent.state, ReliabilityState.needsLook);
      expect(reliabilityFineValue(silent, now: now), isNull);
    });

    test('no other check has one', () {
      for (final id in sourceIds) {
        if (id == ReliabilityCheckIds.lastPushReceived) continue;
        expect(
          reliabilityFineValue(
            check(id.value, ReliabilityState.fine, lastKnownGood: now),
            now: now,
          ),
          isNull,
          reason: id.value,
        );
      }
    });
  });

  group('reliabilityAgo', () {
    test('minutes under an hour, never less than one', () {
      expect(reliabilityAgo(Duration.zero), '1 min');
      expect(reliabilityAgo(const Duration(seconds: 59)), '1 min');
      expect(reliabilityAgo(const Duration(minutes: 5, seconds: 50)), '5 min');
      expect(reliabilityAgo(const Duration(minutes: 59)), '59 min');
    });

    test('hours under a day', () {
      expect(reliabilityAgo(const Duration(hours: 1)), '1 h');
      expect(reliabilityAgo(const Duration(hours: 23, minutes: 59)), '23 h');
    });

    test('days after that', () {
      expect(reliabilityAgo(const Duration(days: 1)), '1 d');
      expect(reliabilityAgo(const Duration(days: 6, hours: 23)), '6 d');
    });
  });

  group('reliabilityAgoWords', () {
    void expectWords(Duration since, String key, String n) {
      final words = reliabilityAgoWords(since);
      expect(words.key, key);
      expect(words.args, {'n': n});
    }

    test('each unit is a string key with the number in its slot', () {
      expectWords(Duration.zero, LocaleKeys.reliability_ago_minutes, '1');
      expectWords(
        const Duration(minutes: 59),
        LocaleKeys.reliability_ago_minutes,
        '59',
      );
      expectWords(
        const Duration(hours: 23, minutes: 59),
        LocaleKeys.reliability_ago_hours,
        '23',
      );
      expectWords(
        const Duration(days: 6, hours: 23),
        LocaleKeys.reliability_ago_days,
        '6',
      );
    });
  });

  group('reliabilityScreenLayout', () {
    const settings = OpenSystemSettingsFix(DevicePermissionType.notifications);
    const weekly = ReliabilityCheckId('weekly_check');
    const ring = OpenRouteFix('testRing');

    List<String> ids(List<ReliabilityListRow> rows) => [
      for (final row in rows)
        row.group == null ? row.check.id.value : 'group${row.group}',
    ];

    test('with no group every check is a plain row, in order', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.fine),
        check('b', ReliabilityState.needsLook, fix: settings),
      ]);
      final layout = reliabilityScreenLayout(ordered, const []);
      expect(ids(layout.rows), ['b', 'a']);
      expect(layout.rows.first.isPrimary, isTrue);
      expect(layout.rows.last.isPrimary, isFalse);
      expect(layout.below, isEmpty);
    });

    test('a check a group draws never gets a plain row as well', () {
      for (final state in [
        ReliabilityState.fine,
        ReliabilityState.needsLook,
        ReliabilityState.broken,
      ]) {
        final ordered = orderReliabilityChecks([
          check('a', ReliabilityState.fine),
          check('weekly_check', state, fix: ring),
        ]);
        final layout = reliabilityScreenLayout(ordered, const [weekly]);
        expect(
          layout.rows.where((r) => r.group == null).map((r) => r.check.id),
          isNot(contains(weekly)),
          reason: state.name,
        );
        final drawn =
            layout.rows.where((r) => r.group == 0).length + layout.below.length;
        expect(drawn, 1, reason: state.name);
      }
    });

    test('a group whose check needs a look sits above the fine rows', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.fine),
        check('b', ReliabilityState.fine),
        check('weekly_check', ReliabilityState.needsLook, fix: ring),
      ]);
      final layout = reliabilityScreenLayout(ordered, const [weekly]);
      expect(ids(layout.rows), ['group0', 'a', 'b']);
      expect(layout.rows.first.check.fix, ring);
      expect(layout.below, isEmpty);
    });

    test('a group whose check is fine stays under the test row', () {
      final fine = check('weekly_check', ReliabilityState.fine);
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.needsLook, fix: settings),
        fine,
      ]);
      final layout = reliabilityScreenLayout(ordered, const [weekly]);
      expect(ids(layout.rows), ['a']);
      expect(layout.below, [(group: 0, check: fine)]);
    });

    test('a group with no check in the list stays where it was', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.fine),
      ]);
      final layout = reliabilityScreenLayout(ordered, const [weekly]);
      expect(ids(layout.rows), ['a']);
      expect(layout.below, [(group: 0, check: null)]);
      // A group that draws no check at all is the same.
      expect(reliabilityScreenLayout(ordered, const [null]).below, [
        (group: 0, check: null),
      ]);
    });

    test('a broken free row comes before the group, which needs a look', () {
      final ordered = orderReliabilityChecks([
        check('weekly_check', ReliabilityState.needsLook, fix: ring),
        check('a', ReliabilityState.broken, fix: settings),
        check('b', ReliabilityState.fine),
      ]);
      final layout = reliabilityScreenLayout(ordered, const [weekly]);
      expect(ids(layout.rows), ['a', 'group0', 'b']);
    });

    group('the one primary button, with a group in the list', () {
      test('the group has it when it is the first row with a fix', () {
        final ordered = orderReliabilityChecks([
          check('a', ReliabilityState.fine),
          check('weekly_check', ReliabilityState.needsLook, fix: ring),
          check('b', ReliabilityState.needsLook, fix: settings),
        ]);
        final layout = reliabilityScreenLayout(ordered, const [weekly]);
        expect(ids(layout.rows), ['group0', 'b', 'a']);
        expect(
          [for (final row in layout.rows) row.isPrimary],
          [
            true,
            false,
            false,
          ],
        );
      });

      test('a free row before it keeps it, and the group goes ghost', () {
        final ordered = orderReliabilityChecks([
          check('a', ReliabilityState.needsLook, fix: settings),
          check('weekly_check', ReliabilityState.needsLook, fix: ring),
        ]);
        final layout = reliabilityScreenLayout(ordered, const [weekly]);
        expect(ids(layout.rows), ['a', 'group0']);
        expect([for (final row in layout.rows) row.isPrimary], [true, false]);
      });

      test('a row before it with nothing to do leaves it to the group', () {
        final ordered = orderReliabilityChecks([
          check('a', ReliabilityState.needsLook),
          check('weekly_check', ReliabilityState.needsLook, fix: ring),
        ]);
        final layout = reliabilityScreenLayout(ordered, const [weekly]);
        expect([for (final row in layout.rows) row.isPrimary], [false, true]);
      });

      test('there is exactly one, or none', () {
        final ordered = orderReliabilityChecks([
          check('a', ReliabilityState.broken, fix: settings),
          check('weekly_check', ReliabilityState.needsLook, fix: ring),
          check('b', ReliabilityState.needsLook, fix: settings),
          check('c', ReliabilityState.fine),
        ]);
        final layout = reliabilityScreenLayout(ordered, const [weekly]);
        expect(layout.rows.where((r) => r.isPrimary), hasLength(1));
        final allFine = reliabilityScreenLayout(
          orderReliabilityChecks([
            check('a', ReliabilityState.fine),
            check('weekly_check', ReliabilityState.fine),
          ]),
          const [weekly],
        );
        expect(allFine.rows.where((r) => r.isPrimary), isEmpty);
      });
    });
  });

  group('the weekly check as a plain row', () {
    test('it has a title and a line for each of its reasons', () {
      expect(
        reliabilityTitleKey(const ReliabilityCheckId('weekly_check')),
        LocaleKeys.pro_pack_weekly_title,
      );
      String? line(String reason) => reliabilityLineKey(
        check('weekly_check', ReliabilityState.needsLook, reason: reason),
      );
      expect(
        line('weekly_missed'),
        LocaleKeys.weekly_check_line_missed_repeatedly,
      );
      expect(
        line('weekly_token_refused'),
        LocaleKeys.weekly_check_line_token_refused,
      );
      expect(line('weekly_no_token'), LocaleKeys.weekly_check_line_no_token);
    });
  });

  group('reliabilityPrimaryRow', () {
    const settings = OpenSystemSettingsFix(DevicePermissionType.notifications);

    test('the first row that is not fine keeps the primary button', () {
      final ordered = orderReliabilityChecks([
        check('a', ReliabilityState.fine),
        check('b', ReliabilityState.needsLook, fix: settings),
        check('c', ReliabilityState.broken, fix: settings),
        check('d', ReliabilityState.broken, fix: settings),
      ]);
      expect(ordered.map((c) => c.id.value), ['c', 'd', 'b', 'a']);
      expect(reliabilityPrimaryRow(ordered), 0);
    });

    test('a row with nothing to do is passed over', () {
      expect(
        reliabilityPrimaryRow([
          check('a', ReliabilityState.broken),
          check('b', ReliabilityState.needsLook, fix: settings),
          check('c', ReliabilityState.needsLook, fix: settings),
        ]),
        1,
      );
    });

    test('there is none when every row is fine, or nothing can be done', () {
      expect(reliabilityPrimaryRow(const []), isNull);
      expect(
        reliabilityPrimaryRow([
          check('a', ReliabilityState.fine),
          check('b', ReliabilityState.fine, fix: settings),
        ]),
        isNull,
      );
      expect(
        reliabilityPrimaryRow([check('a', ReliabilityState.broken)]),
        isNull,
      );
    });

    test('a check from a later source counts like any other', () {
      expect(
        reliabilityPrimaryRow(
          orderReliabilityChecks([
            check('notifications', ReliabilityState.fine),
            check(
              laterId,
              ReliabilityState.needsLook,
              fix: const OpenRouteFix('testRing'),
            ),
          ]),
        ),
        0,
      );
    });
  });

  group('reliabilityRowTarget', () {
    test('a permission row opens the permissions screen', () {
      for (final id in [
        ReliabilityCheckIds.notifications,
        ReliabilityCheckIds.fullScreenAlarm,
        ReliabilityCheckIds.batteryOptimization,
        ReliabilityCheckIds.alarms,
      ]) {
        expect(
          reliabilityRowTarget(id),
          ReliabilityRowTarget.permissions,
          reason: id.value,
        );
      }
    });

    test('the Sleep settings row opens the steps', () {
      expect(
        reliabilityRowTarget(ReliabilityCheckIds.phoneMaker),
        ReliabilityRowTarget.makerGuide,
      );
    });

    test('any other row opens nothing', () {
      for (final id in [
        ReliabilityCheckIds.timeSensitive,
        ReliabilityCheckIds.pushTokenConfirmed,
        ReliabilityCheckIds.lastPushReceived,
        ReliabilityCheckIds.systemUpdate,
        ReliabilityCheckIds.missedAlarm,
        const ReliabilityCheckId(laterId),
      ]) {
        expect(
          reliabilityRowTarget(id),
          ReliabilityRowTarget.none,
          reason: id.value,
        );
      }
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
    // The rows of the screen have no face. The Past checks list takes the
    // face of a state from here, and it is the face the header uses.
    test('a fine check and one not on this phone have no face', () {
      expect(reliabilityStateFace(ReliabilityState.fine), isNull);
      expect(reliabilityStateFace(ReliabilityState.notOnThisPhone), isNull);
    });

    test('a state that needs a look has the face of the look header', () {
      final header = reliabilityHeadlineView(ReliabilityHeadline.needsLook);
      expect(header.face, FaceState.skeptical);
      expect(reliabilityStateFace(ReliabilityState.needsLook), header.face);
    });

    test('a broken state has the face of the broken header', () {
      final header = reliabilityHeadlineView(ReliabilityHeadline.broken);
      expect(header.face, FaceState.sad);
      expect(reliabilityStateFace(ReliabilityState.broken), header.face);
    });

    test('a state that asks for nothing has no face and the rest do', () {
      for (final state in ReliabilityState.values) {
        expect(
          reliabilityStateFace(state) == null,
          !reliabilityNeedsAction(state),
          reason: state.name,
        );
      }
    });
  });

  group('splitReliabilityRows', () {
    ReliabilityListRow row(String id, ReliabilityState state) =>
        ReliabilityListRow(check: check(id, state), isPrimary: false);

    test('puts the rows that need action in one list, in order', () {
      final split = splitReliabilityRows([
        row('a', ReliabilityState.broken),
        row('b', ReliabilityState.needsLook),
        row('c', ReliabilityState.fine),
        row('d', ReliabilityState.fine),
      ]);
      expect(split.attention.map((r) => r.check.id.value), ['a', 'b']);
      expect(split.calm.map((r) => r.check.id.value), ['c', 'd']);
    });

    test('an all fine list has no card', () {
      final split = splitReliabilityRows([row('a', ReliabilityState.fine)]);
      expect(split.attention, isEmpty);
    });
  });

  test('a fix button announces its check after its action', () {
    expect(
      reliabilityActionAnnouncement('Open settings', 'Notifications'),
      'Open settings, Notifications',
    );
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
