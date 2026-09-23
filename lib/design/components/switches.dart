import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// Custom iOS-style toggle switch (48x28) matching index.html .tsw.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bg = value ? colors.highlight : colors.hairline;
    final knobOffset = value ? 20.0 : 0.0;

    return MouseRegion(
      cursor: onChanged != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onChanged != null ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: AppDurations.quick,
          curve: AppCurves.easeSpring,
          width: 48,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Radii.fullAll,
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: AppDurations.quick,
                curve: AppCurves.easeSpring,
                top: 3,
                left: 3 + knobOffset,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    boxShadow: AppShadows.lightSm,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Setting toggle row matching index.html .tog.
class AppToggleRow extends StatelessWidget {
  const AppToggleRow({
    required this.title,
    required this.value,
    this.subtitle,
    this.onChanged,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  AnimatedSize(
                    duration: context.motion(AppDurations.base),
                    curve: AppCurves.easeOut,
                    alignment: Alignment.topLeft,
                    child: AnimatedSwitcher(
                      duration: context.motion(AppDurations.base),
                      switchInCurve: AppCurves.easeOut,
                      switchOutCurve: AppCurves.easeOut,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Text(
                        subtitle!,
                        key: ValueKey(subtitle),
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: colors.ink3,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
