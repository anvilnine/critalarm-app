import 'package:critalarm/features/pro_pack/presentation/widgets/pro_pack_reliability_group.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:flutter/widgets.dart';

/// Draws one group of rows under the free ones on the Reliability screen,
/// with its own header if it wants one.
typedef ReliabilityGroupBuilder =
    Widget Function(BuildContext context, ReliabilitySnapshot snapshot);

/// The groups the screen draws after the rows built from the checks, in this
/// order. One today: the Pro rows.
///
/// To add a group, append a builder here. The screen's layout code does not
/// change: it draws each group in the list, with the same gap between them.
/// A single row that comes from a new check does not need a group at all.
/// See `ReliabilityScreen`.
const List<ReliabilityGroupBuilder> reliabilityExtraGroups = [
  _proPackGroup,
];

Widget _proPackGroup(BuildContext context, ReliabilitySnapshot snapshot) =>
    const ProPackReliabilityGroup();
