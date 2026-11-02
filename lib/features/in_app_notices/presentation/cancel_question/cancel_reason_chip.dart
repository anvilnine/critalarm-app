import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// One reason on the cancel question. A pill that is picked, free to pick, or
/// out of reach once another pill was picked.
///
/// It takes the shape of the pill on the history filter sheet. That one is
/// private, and this sheet needs the same look with a label that may wrap to
/// two lines, so the pill is drawn again here.
class CancelReasonChip extends StatelessWidget {
  const CancelReasonChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// Already translated.
  final String label;

  /// This is the reason that was picked.
  final bool isSelected;

  /// Null when another reason was picked: the pill is dimmed and takes no tap.
  final VoidCallback? onTap;

  /// How dim a pill is once another one was picked.
  static const double disabledOpacity = 0.45;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final pill = Semantics(
      button: true,
      selected: isSelected,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: AppTapTarget(
        minWidth: 0,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.fullAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s4,
              vertical: Spacing.s2,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.ink : Colors.transparent,
              borderRadius: Radii.fullAll,
              border: Border.all(
                color: isSelected
                    ? colors.ink
                    : colors.ink.withValues(alpha: 0.22),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: AppTypography.small(
                isSelected ? colors.canvas : colors.ink,
              ),
            ),
          ),
        ),
      ),
    );

    if (isSelected || onTap != null) return pill;
    return Opacity(opacity: disabledOpacity, child: pill);
  }
}
