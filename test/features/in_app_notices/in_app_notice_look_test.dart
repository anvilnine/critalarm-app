import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final missed = MissedAlarmNotice(
    incidentIds: const ['inc_1'],
    topic: 'prod-db',
    at: DateTime.utc(2026, 10, 7, 9),
    reason: MissedReason.noPushReached,
  );

  group('InAppNoticeState.asksForLook', () {
    test('a missed alarm, missed weekly checks and a phone update ask', () {
      expect(
        InAppNoticeState(
          noticeType: InAppNoticeType.missedAlarm,
          missedAlarm: missed,
        ).asksForLook,
        isTrue,
      );
      for (final type in [
        InAppNoticeType.weeklyCheck,
        InAppNoticeType.systemUpdate,
      ]) {
        expect(InAppNoticeState(noticeType: type).asksForLook, isTrue);
      }
    });

    test('a missed alarm entry with nothing in it does not', () {
      expect(
        const InAppNoticeState(
          noticeType: InAppNoticeType.missedAlarm,
        ).asksForLook,
        isFalse,
      );
    });

    test('a card that is closing does not', () {
      expect(
        const InAppNoticeState(
          noticeType: InAppNoticeType.weeklyCheck,
          isDismissing: true,
        ).asksForLook,
        isFalse,
      );
    });

    test('every other notice leaves the hero alone', () {
      for (final type in [
        InAppNoticeType.none,
        InAppNoticeType.noServer,
        InAppNoticeType.criticalHealth,
        InAppNoticeType.batteryOptimization,
        InAppNoticeType.proEnding,
        InAppNoticeType.accountBackup,
      ]) {
        expect(InAppNoticeState(noticeType: type).asksForLook, isFalse);
      }
    });
  });

  test('a look and a break each have one face', () {
    expect(needsLookFace, FaceState.skeptical);
    expect(brokenFace, FaceState.sad);
    expect(needsLookFace, isNot(brokenFace));
  });
}
