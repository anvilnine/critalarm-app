import 'package:critalarm/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Simulated native system permission prompt preview.
///
/// Previews the OS-level permission dialog before prompting, visually guiding
/// the user to choose 'Allow'.
class PermissionDialogPreview extends StatelessWidget {
  const PermissionDialogPreview({
    required this.title,
    required this.message,
    required this.allowLabel,
    required this.denyLabel,
    super.key,
    this.isCritical = false,
  });

  final String title;
  final String message;
  final String allowLabel;
  final String denyLabel;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: isApple
            ? _buildIosPreview(context, colors)
            : _buildAndroidPreview(context, colors),
      ),
    );
  }

  Widget _buildIosPreview(BuildContext context, AppColors colors) {
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
          Divider(
            height: 1,
            thickness: 1,
            color: colors.hairline.withValues(alpha: 0.4),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text(
                    denyLabel,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      color: colors.ink3,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: colors.hairline.withValues(alpha: 0.4),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.ink.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        allowLabel,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.ink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TAP',
                          style: TextStyle(
                            fontFamily: AppTypography.fontMono,
                            fontFamilyFallback:
                                AppTypography.fontMonoFallbacks,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            color: colors.canvas,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      allowLabel,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.ink,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'TAP',
                        style: TextStyle(
                          fontFamily: AppTypography.fontMono,
                          fontFamilyFallback: AppTypography.fontMonoFallbacks,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          color: colors.canvas,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
