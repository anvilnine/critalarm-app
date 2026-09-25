import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// Segmented pill control following Crit Alarm design specifications.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.items,
    required this.selectedItem,
    required this.labelBuilder,
    required this.onChanged,
    super.key,
  });

  final List<T> items;
  final T selectedItem;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _SegmentItem(
                label: labelBuilder(item),
                isSelected: item == selectedItem,
                onTap: () => onChanged(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          // easeOut, not easeSpring: the spring overshoots past 1, and a shadow
          // animating to none then gets a negative blur, which Flutter rejects.
          child: AnimatedContainer(
            duration: context.motion(AppDurations.quick),
            curve: AppCurves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? colors.surface : Colors.transparent,
              borderRadius: Radii.fullAll,
              boxShadow: isSelected ? AppShadows.lightSm : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.ink : colors.ink3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
