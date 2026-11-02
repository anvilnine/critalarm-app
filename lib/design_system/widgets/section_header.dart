import 'package:critalarm/core/l10n/upper_for_locale.dart';
import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:flutter/material.dart';

/// A section title row with an optional trailing text action
/// (e.g. "See all"). Gives every screen the same section rhythm.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            upperInContext(title, context),
            style: textTheme.titleMedium,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: textTheme.labelLarge?.copyWith(
                color: context.appColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
