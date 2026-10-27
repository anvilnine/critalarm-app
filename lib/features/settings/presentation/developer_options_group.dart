import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// The room between two rows of the Developer options list.
const double developerRowGap = 6;

/// A section of Developer options: its header, then its rows with the
/// list's gap between them.
class DeveloperOptionsGroup extends StatelessWidget {
  const DeveloperOptionsGroup({
    required this.title,
    required this.rows,
    super.key,
  });

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionHeader(title),
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: developerRowGap),
          row,
        ],
      ],
    );
  }
}
