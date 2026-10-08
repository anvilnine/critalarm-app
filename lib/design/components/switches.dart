import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// Where a switch sits, which sets how it is drawn.
enum AppSwitchVariant {
  /// On a cream row or a white sheet. 48 by 28.
  standard,

  /// On the dark status card. A little larger (56 by 32, with a 44 point
  /// touch target) and outlined with the `panelLine` token. The standard off
  /// track is a faint dark tint that all but disappears on the panel, and
  /// the cobalt on track sits at about 2.4 to 1 against it, so the outline
  /// is what shows where the control ends.
  panel,
}

/// Custom iOS-style toggle switch (48x28) matching index.html .tsw.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    this.onChanged,
    this.semanticLabel,
    this.semanticHint,
    this.variant = AppSwitchVariant.standard,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// What the switch turns on or off, read by VoiceOver and TalkBack.
  final String? semanticLabel;

  /// Extra context read after the label and state, such as a row subtitle.
  final String? semanticHint;

  /// [AppSwitchVariant.panel] for a switch on the dark status card.
  final AppSwitchVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPanel = variant == AppSwitchVariant.panel;

    final width = isPanel ? 56.0 : 48.0;
    final height = isPanel ? 32.0 : 28.0;
    final inset = isPanel ? 4.0 : 3.0;
    final knob = isPanel ? 24.0 : 22.0;
    final knobOffset = value ? width - 2 * inset - knob : 0.0;

    final bg = value
        ? colors.highlight
        : isPanel
        ? colors.onPanel.withValues(alpha: 0.16)
        : colors.switchOff;

    final duration = context.motion(AppDurations.quick);

    final track = AnimatedContainer(
      duration: duration,
      curve: AppCurves.easeSpring,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.fullAll,
      ),
      // Drawn over the track, so it does not move the knob.
      foregroundDecoration: isPanel
          ? BoxDecoration(
              borderRadius: Radii.fullAll,
              border: Border.all(color: colors.panelLine, width: 1.5),
            )
          : null,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: duration,
            curve: AppCurves.easeSpring,
            top: inset,
            left: inset + knobOffset,
            child: Container(
              width: knob,
              height: knob,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? colors.onHighlight : colors.switchThumbOff,
                boxShadow: AppShadows.lightSm,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      hint: semanticHint,
      child: MouseRegion(
        cursor: onChanged != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: isPanel ? HitTestBehavior.opaque : null,
          onTap: onChanged != null ? () => onChanged!(!value) : null,
          child: isPanel
              ? SizedBox(
                  width: width,
                  height: 44,
                  child: Center(child: track),
                )
              : track,
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
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Small button shown just before the switch, such as an info button.
  final Widget? action;

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
            // The switch carries the title and subtitle, so a screen reader
            // hears one "Title, switch, on" instead of a silent switch.
            child: ExcludeSemantics(
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
          ),
          const SizedBox(width: 12),
          if (action != null) ...[
            action!,
            const SizedBox(width: 8),
          ],
          AppSwitch(
            value: value,
            onChanged: onChanged,
            semanticLabel: title,
            semanticHint: subtitle,
          ),
        ],
      ),
    );
  }
}
