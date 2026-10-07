import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/settings/presentation/settings_reliability_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

ReliabilityCheck check(String id, ReliabilityState state) =>
    ReliabilityCheck(id: ReliabilityCheckId(id), state: state);

void main() {
  test('says it is checking until the first read ends', () {
    final row = SettingsReliabilityRow.from(const ReliabilitySnapshot());

    expect(row.headline, ReliabilityHeadline.loading);
    expect(row.subtitleKey, LocaleKeys.reliability_loading);
    expect(row.faceState, FaceState.watching);
    expect(row.hasIssues, isFalse);
  });

  test('all fine: a happy face, no count', () {
    final row = SettingsReliabilityRow.from(
      ReliabilitySnapshot(
        checks: [check('a', ReliabilityState.fine)],
        loaded: true,
      ),
    );

    expect(row.faceState, FaceState.happy);
    expect(row.subtitleKey, LocaleKeys.reliability_overall_fine_line);
    expect(row.hasIssues, isFalse);
  });

  test('a check that needs a look shows the count', () {
    final row = SettingsReliabilityRow.from(
      ReliabilitySnapshot(
        checks: [
          check('a', ReliabilityState.fine),
          check('b', ReliabilityState.needsLook),
        ],
        overall: ReliabilityState.needsLook,
        loaded: true,
      ),
    );

    expect(row.faceState, FaceState.skeptical);
    expect(row.issueCount, 1);
  });

  test('a broken check shows the sad face and the count', () {
    final row = SettingsReliabilityRow.from(
      ReliabilitySnapshot(
        checks: [
          check('a', ReliabilityState.broken),
          check('b', ReliabilityState.needsLook),
        ],
        overall: ReliabilityState.broken,
        loaded: true,
      ),
    );

    expect(row.faceState, FaceState.sad);
    expect(row.subtitleKey, LocaleKeys.reliability_overall_broken_line);
    expect(row.issueCount, 2);
  });
}
