import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// The dot half of a pick-one row. 22x22, seam ring, accent fill when picked.
class AppRadio extends StatelessWidget {
  const AppRadio({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedContainer(
      duration: context.motion(AppDurations.quick),
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
    this.waveform,
    this.badge,
    this.onTap,
    super.key,
  });

  final String title;

  /// Second line, for a length or a file size.
  final String? meta;

  /// Third line, used when a sound cannot ring the alarm on this platform.
  final String? note;
  final Widget? leading;

  /// A waveform under the title, for sound rows. With one, the meta line
  /// moves up next to the title so the row stays two lines tall.
  final Widget? waveform;

  /// A small widget after the title, such as the Pro pill on an option only
  /// Pro can pick. Ignored on a row with a [waveform].
  final Widget? badge;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final titleText = Text(
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
    );
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
            duration: context.motion(AppDurations.quick),
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
                      if (waveform != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(child: titleText),
                            if (meta != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                meta!,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontMono,
                                  fontFamilyFallback:
                                      AppTypography.fontMonoFallbacks,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: colors.ink3,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 22,
                          width: double.infinity,
                          child: waveform,
                        ),
                      ] else if (badge != null)
                        Row(
                          children: [
                            Flexible(child: titleText),
                            const SizedBox(width: 8),
                            badge!,
                          ],
                        )
                      else
                        titleText,
                      if (meta != null && waveform == null) ...[
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
