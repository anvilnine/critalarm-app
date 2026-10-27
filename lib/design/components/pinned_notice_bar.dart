import 'package:critalarm/design/components/dismiss_cross.dart';
import 'package:critalarm/design/components/tap_target.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A one line notice that floats in the scaffold's bottom slot, over the list.
///
/// Rows in that list are a white surface too, so this bar leans on a pill
/// shape, a hairline and a real shadow to read as something sitting on top of
/// the list rather than another row in it.
///
/// The whole bar opens the explainer. The link beside the title is the hint
/// that there is more to read, not a tap target of its own, so the thumb has
/// the full width to hit. Only the cross does something else.
class AppPinnedNoticeBar extends StatelessWidget {
  const AppPinnedNoticeBar({
    required this.face,
    required this.title,
    required this.linkLabel,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  /// Which face to show. The caller picks it, so the bar says nothing about
  /// what the notice is for.
  final FaceState face;

  /// Short enough to sit on one line next to the link.
  final String title;

  /// The words that read as a link, in cobalt, right after the title.
  final String linkLabel;

  /// Opens the explainer.
  final VoidCallback onTap;

  /// Puts the notice away.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.fullAll,
        border: Border.all(color: colors.hairline),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.fullAll,
          child: Padding(
            // The cross is a 48 box now, not 44, so the bar gives up 2 of
            // its 4 on every side the box reaches and stays 52 high.
            padding: const EdgeInsets.fromLTRB(Spacing.s3, 2, 2, 2),
            child: Row(
              children: [
                FaceWidget(state: face, size: 20),
                const SizedBox(width: Spacing.s2),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: title),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: linkLabel,
                          style: TextStyle(
                            color: colors.cobalt,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: colors.ink,
                    ),
                  ),
                ),
                // 2 less than the 8 it was: the cross box is 4 wider and the
                // bar's right padding gave up 2 of that.
                const SizedBox(width: Spacing.s2 - 2),
                AppDismissCross(
                  onPressed: onDismiss,
                  label: LocaleKeys.common_close.tr(),
                  tapSize: kMinTapTarget,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
