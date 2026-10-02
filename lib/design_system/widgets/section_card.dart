import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:flutter/material.dart';

/// A titled content section on a mat panel (themed Card: elevated mat fill,
/// seam border, [AppSectionHeader] title).
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  // The one list header the app uses, not a style of its own.
                  child: AppSectionHeader(title, padding: EdgeInsets.zero),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: Spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
