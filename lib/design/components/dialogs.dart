import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The two faces of a dialog card: a light [AppDialogSkin.surface] for
/// prompts, and the dark [AppDialogSkin.panel] that the tour spotlight card
/// already uses.
enum AppDialogSkin { surface, panel }

/// One button in a dialog, paired with the value it returns.
class AppDialogAction<T> {
  const AppDialogAction({
    required this.label,
    this.value,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final T? value;
  final AppButtonVariant variant;
}

/// A centered card over a dimmed scrim, matching the design system.
///
/// [body] is rendered with [AppBulletedText], so a line starting with `• ` is
/// drawn as a bullet. [content] is an arbitrary widget (an input, a face) shown
/// in place of [body] when set.
class AppDialog extends StatelessWidget {
  const AppDialog({
    this.kicker,
    this.title,
    this.body,
    this.content,
    this.leading,
    this.actions = const [],
    this.skin = AppDialogSkin.surface,
    this.alignActions = MainAxisAlignment.end,
    super.key,
  });

  final String? kicker;
  final String? title;
  final String? body;
  final Widget? content;
  final Widget? leading;
  final List<Widget> actions;
  final AppDialogSkin skin;
  final MainAxisAlignment alignActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPanel = skin == AppDialogSkin.panel;

    final kickerColor = isPanel ? colors.onPanelMuted : colors.ink3;
    final titleColor = isPanel ? colors.onPanel : colors.ink;
    final bodyColor = isPanel ? colors.onPanel : colors.ink2;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: isPanel ? colors.panel : colors.surface,
          borderRadius: isPanel ? Radii.lgAll : Radii.xlAll,
          border: isPanel ? Border.all(color: colors.panelLine) : null,
          boxShadow: AppShadows.shadowLg(isDark: isDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(height: 12),
            ],
            if (kicker != null) ...[
              Text(
                kicker!,
                style: AppTypography.label(kickerColor).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02 * 20,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (content != null)
              content!
            else if (body != null)
              AppBulletedText(
                body!,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 14,
                  height: 1.45,
                  color: bodyColor,
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: alignActions,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Body text where a line starting with `• ` is a bullet, with the wrapped
/// part lined up under its first word rather than under the dot.
class AppBulletedText extends StatelessWidget {
  const AppBulletedText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  static const _bullet = '• ';

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: lines[i].startsWith(_bullet)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_bullet, style: style),
                      Expanded(
                        child: Text(
                          lines[i].substring(_bullet.length),
                          style: style,
                        ),
                      ),
                    ],
                  )
                : Text(lines[i], style: style),
          ),
      ],
    );
  }
}

/// Shows an [AppDialog] and resolves with the value of the action tapped, or
/// null if it is dismissed.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  String? kicker,
  String? title,
  String? body,
  Widget? leading,
  List<AppDialogAction<T>> actions = const [],
  AppDialogSkin skin = AppDialogSkin.surface,
  MainAxisAlignment alignActions = MainAxisAlignment.end,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      final colors = dialogContext.appColors;
      final isPanel = skin == AppDialogSkin.panel;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: AppDialog(
          kicker: kicker,
          title: title,
          body: body,
          leading: leading,
          skin: skin,
          alignActions: alignActions,
          actions: [
            for (final action in actions)
              AppButton(
                label: action.label,
                variant: action.variant,
                size: AppButtonSize.sm,
                foregroundColor:
                    isPanel && action.variant == AppButtonVariant.ghost
                    ? colors.onPanel
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(action.value),
              ),
          ],
        ),
      );
    },
  );
}
