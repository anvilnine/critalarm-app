import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The dot half of a pick-one row. 22x22, seam ring, accent fill when picked.
class AppRadio extends StatelessWidget {
  const AppRadio({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedContainer(
      duration: AppDurations.quick,
      curve: AppCurves.easeSpring,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.highlight : colors.canvas,
        border: Border.all(
          color: selected ? colors.highlight : colors.hairline,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface,
                ),
              ),
            )
          : null,
    );
  }
}

/// One row in a pick-one list: title, meta line, an optional leading control
/// (the play or stop button in the sound picker) and the radio dot.
class AppRadioRow extends StatelessWidget {
  const AppRadioRow({
    required this.title,
    required this.selected,
    this.meta,
    this.note,
    this.leading,
    this.onTap,
    super.key,
  });

  final String title;

  /// Second line, for a length or a file size.
  final String? meta;

  /// Third line, used when a sound cannot ring the alarm on this platform.
  final String? note;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: title,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppDurations.quick,
            curve: AppCurves.easeSpring,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.ash : colors.cream,
              borderRadius: Radii.mdAll,
              border: Border.all(
                color: selected ? colors.highlight : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta!,
                          style: TextStyle(
                            fontFamily: AppTypography.fontMono,
                            fontFamilyFallback: AppTypography.fontMonoFallbacks,
                            fontSize: 12,
                            color: colors.ink3,
                          ),
                        ),
                      ],
                      if (note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          note!,
                          style: TextStyle(
                            fontFamily: AppTypography.fontBody,
                            fontFamilyFallback: AppTypography.fontBodyFallbacks,
                            fontSize: 11,
                            color: colors.high,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppRadio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
