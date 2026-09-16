import 'package:critalarm/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Simulated native system permission prompt preview.
///
/// Previews the OS-level permission dialog before prompting, visually guiding
/// the user to choose 'Allow'. Tapping anywhere on it opens the real prompt,
/// because people read it as the real thing and tap it.
class PermissionDialogPreview extends StatelessWidget {
  const PermissionDialogPreview({
    required this.title,
    required this.message,
    required this.allowLabel,
    required this.denyLabel,
    super.key,
    this.summaryLabel,
    this.isCritical = false,
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String message;
  final String allowLabel;
  final String denyLabel;

  /// iOS only, and only on the notification ask: the middle choice that files
  /// pages into the Scheduled Summary instead of delivering them.
  final String? summaryLabel;

  final bool isCritical;

  /// Opens the real system prompt.
  final VoidCallback? onTap;

  /// What a screen reader announces for the card as a whole.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        // One control, not three. A screen reader would otherwise read the
        // drawn Allow / Don't Allow rows as if they were buttons, and tapping
        // one of them does nothing: the whole card opens the real prompt.
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: semanticLabel,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: isApple
                ? _buildIosPreview(context, colors)
                : _buildAndroidPreview(context, colors),
          ),
        ),
      ),
    );
  }

  Widget _buildIosPreview(BuildContext context, AppColors colors) {
    final summary = summaryLabel;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.hairline.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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

          // The notification ask has three choices on iOS, so they stack. The
          // alarm ask has two, so they sit side by side.
          if (summary != null) ...[
            _iosRow(colors, allowLabel, isPreferred: true),
            _hairline(colors),
            _iosRow(colors, summary, isMuted: true),
            _hairline(colors),
            _iosRow(colors, denyLabel, isMuted: true, isLast: true),
          ] else
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _iosRow(colors, denyLabel, isMuted: true)),
                  Container(
                    width: 1,
                    color: colors.hairline.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: _iosRow(colors, allowLabel, isPreferred: true),
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

  /// One choice in the iOS alert. The preferred one is filled and bold, the
  /// rest are dimmed, so the eye lands on the one that keeps pages coming.
  /// No marker points at it: Apple's HIG bans drawing a cue at Allow.
  Widget _iosRow(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
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
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidPreview(BuildContext context, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.hairline.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isCritical
                    ? Icons.emergency_rounded
                    : Icons.notifications_active_rounded,
                color: colors.ink,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.4,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.ink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.ink.withValues(alpha: 0.2)),
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
        ],
      ),
    );
  }
}
