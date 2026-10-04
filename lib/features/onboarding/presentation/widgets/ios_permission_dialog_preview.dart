import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_preview_frame.dart';
import 'package:flutter/material.dart';

/// A drawn copy of an iOS permission alert.
///
/// Only iOS steps use it. The notification alert has three choices, so they
/// stack; pass [summaryLabel] for the middle one. The alarm alert has two,
/// which sit side by side.
class IosPermissionDialogPreview extends StatelessWidget {
  const IosPermissionDialogPreview({
    required this.title,
    required this.message,
    required this.allowLabel,
    required this.denyLabel,
    super.key,
    this.summaryLabel,
  });

  final String title;
  final String message;
  final String allowLabel;
  final String denyLabel;

  /// The notification ask only: the middle choice that files pages into the
  /// Scheduled Summary instead of delivering them.
  final String? summaryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final summary = summaryLabel;

    return DecoratedBox(
      decoration: permissionPreviewDecoration(colors, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.25,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.35,
                    color: colors.ink2,
                  ),
                ),
              ],
            ),
          ),
          _hairline(colors),
          if (summary != null) ...[
            _row(colors, allowLabel, isPreferred: true),
            _hairline(colors),
            _row(colors, summary, isMuted: true),
            _hairline(colors),
            _row(colors, denyLabel, isMuted: true, isLast: true),
          ] else
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _row(colors, denyLabel, isMuted: true)),
                  Container(
                    width: 1,
                    color: colors.hairline.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: _row(colors, allowLabel, isPreferred: true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hairline(AppColors colors) => Container(
    height: 1,
    color: colors.hairline.withValues(alpha: 0.4),
  );

  /// One choice in the alert. The preferred one is filled and bold, the rest
  /// are dimmed, so the eye lands on the one that keeps pages coming. No
  /// marker points at it: Apple's HIG bans drawing a cue at Allow.
  Widget _row(
    AppColors colors,
    String label, {
    bool isPreferred = false,
    bool isMuted = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      decoration: BoxDecoration(
        color: isPreferred ? colors.ink.withValues(alpha: 0.05) : null,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(18))
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontWeight: isPreferred ? FontWeight.w700 : FontWeight.w400,
          fontSize: 15,
          color: isMuted ? colors.ink3 : colors.ink,
        ),
      ),
    );
  }
}
