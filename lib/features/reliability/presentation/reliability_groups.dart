import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_source.dart';
import 'package:critalarm/features/weekly_check/presentation/widgets/weekly_check_group.dart';
import 'package:flutter/widgets.dart';

/// Draws one group of rows on the Reliability screen, with its own header
/// if it wants one.
///
/// [check] is the check the group draws, when it draws one and the list
/// has it. [isPrimary] says its action is the screen's one primary button.
typedef ReliabilityGroupBuilder =
    Widget Function(
      BuildContext context,
      ReliabilitySnapshot snapshot, {
      required bool isPrimary,
      ReliabilityCheck? check,
    });

/// One group, and the check it draws by itself, if any.
///
/// A group that names a [checkId] draws that check, so the screen gives it
/// no plain row. While the check is not fine the group moves up to the
/// check's place in the list. See `reliabilityScreenLayout`.
@immutable
final class ReliabilityGroup {
  const ReliabilityGroup({
    required this.builder,
    this.checkId,
    this.plainTail,
  });

  final ReliabilityGroupBuilder builder;
  final ReliabilityCheckId? checkId;

  /// The part of the group that stays plain when [builder] draws it inside
  /// the card of rows that need action. The screen puts it at the end of its
  /// plain list. Null when the group has no such part. The widget brings its
  /// own rule and draws nothing when it has nothing to show.
  final WidgetBuilder? plainTail;
}

/// The groups the screen draws after the rows built from the checks, in this
/// order. One today: the weekly delivery check.
///
/// To add a group, append one here. The screen's layout code does not
/// change: it draws each group in the list, with the same gap between them.
/// A single row that comes from a new check does not need a group at all.
/// See `ReliabilityScreen`.
const List<ReliabilityGroup> reliabilityExtraGroups = [
  ReliabilityGroup(
    builder: _weeklyCheckGroup,
    checkId: WeeklyCheckSource.id,
    plainTail: _weeklyCheckTail,
  ),
];

Widget _weeklyCheckTail(BuildContext context) => const WeeklyCheckRoundsTail();

Widget _weeklyCheckGroup(
  BuildContext context,
  ReliabilitySnapshot snapshot, {
  required bool isPrimary,
  ReliabilityCheck? check,
}) => WeeklyCheckGroup(check: check, isPrimary: isPrimary);
