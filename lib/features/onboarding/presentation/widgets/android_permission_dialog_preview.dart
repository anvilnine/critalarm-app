import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_preview_frame.dart';
import 'package:flutter/material.dart';

/// A drawn copy of an Android permission dialog: an icon, a question, and
/// two text buttons at the bottom right.
///
/// Only Android steps use it, and only the ones that open a dialog. A step
/// that opens a settings page uses [AndroidSettingsSwitchPreview].
class AndroidPermissionDialogPreview extends StatelessWidget {
  const AndroidPermissionDialogPreview({
    required this.icon,
    required this.title,
    required this.allowLabel,
    required this.denyLabel,
    this.message,
    super.key,
  });

  final IconData icon;
  final String title;

  /// The dialog's body text. Null for a dialog that has none.
  final String? message;
  final String allowLabel;
  final String denyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: permissionPreviewDecoration(colors, 24),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.ink, size: 24),
              const SizedBox(width: 12),
              Expanded(child: _AndroidPreviewTitle(title)),
            ],
          ),
          if (message case final message?) ...[
            const SizedBox(height: 12),
            _AndroidPreviewMessage(message),
          ],
          const SizedBox(height: 20),
          // Wraps, so both choices stay on the card at large text sizes.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  denyLabel,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colors.ink3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.ink.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    allowLabel,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A drawn copy of a row on an Android settings page: the name of the
/// setting with its switch, turned on.
///
/// For a step whose permission is a switch in Settings. Drawing a dialog
/// there would promise a pop-up the phone never shows.
class AndroidSettingsSwitchPreview extends StatelessWidget {
  const AndroidSettingsSwitchPreview({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: permissionPreviewDecoration(colors, 24),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(child: _AndroidPreviewTitle(title)),
          const SizedBox(width: 12),
          // Drawn on, the way the user should leave it. It is a picture:
          // the frame around the card is the only control.
          const AppSwitch(value: true),
        ],
      ),
    );
  }
}

class _AndroidPreviewTitle extends StatelessWidget {
  const _AndroidPreviewTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.fontDisplay,
        fontFamilyFallback: AppTypography.fontDisplayFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: context.appColors.ink,
      ),
    );
  }
}

class _AndroidPreviewMessage extends StatelessWidget {
  const _AndroidPreviewMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.4,
        color: context.appColors.ink2,
      ),
    );
  }
}
