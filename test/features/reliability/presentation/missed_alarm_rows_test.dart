import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the missed alarm row has a title', () {
    expect(
      reliabilityTitleKey(ReliabilityCheckIds.missedAlarm),
      LocaleKeys.reliability_check_missed_alarm,
    );
  });

  test('every missed reason has its own line', () {
    final lines = {
      for (final reason in MissedReason.values)
        reliabilityLineKey(
          ReliabilityCheck(
            id: ReliabilityCheckIds.missedAlarm,
            state: ReliabilityState.needsLook,
            reason: 'missed_${reason.code}',
          ),
        ),
    };
    expect(lines, hasLength(MissedReason.values.length));
    expect(lines, isNot(contains(LocaleKeys.reliability_line_look_generic)));
  });
}
