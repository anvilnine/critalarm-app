import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Expressive stage container matching index.html .stage.
/// Displays a face, primary word headline, optional mono topic name,
/// and sub text.
class AppStage extends StatelessWidget {
  const AppStage({
    this.faceState,
    this.faceSize = 190.0,
    this.isLive = false,
    this.word,
    this.wordIsBig = false,
    this.topicName,
    this.sub,
    this.padding = const EdgeInsets.fromLTRB(24, Spacing.s4, 24, 0),
    this.faceWidget,
    super.key,
  });

  final FaceState? faceState;
  final double faceSize;
  final bool isLive;
  final String? word;
  final bool wordIsBig;
  final String? topicName;
  final String? sub;
  final EdgeInsetsGeometry padding;
  final Widget? faceWidget;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (faceWidget != null)
            faceWidget!
          else if (faceState != null)
            FaceWidget(
              state: faceState!,
              size: faceSize,
              isLive: isLive,
            ),
          if (word != null) ...[
            SizedBox(height: faceSize > 120 ? Spacing.s5 : Spacing.s3),
            Text(
              word!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontDisplay,
                fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                fontWeight: FontWeight.w800,
                fontSize: wordIsBig ? 56 : 44,
                letterSpacing: -0.04 * (wordIsBig ? 56 : 44),
                height: 1,
                color: colors.onCanvas,
              ),
            ),
          ],
          if (topicName != null) ...[
            const SizedBox(height: Spacing.s3),
            Text(
              topicName!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: colors.onCanvas,
              ),
            ),
          ],
          if (sub != null) ...[
            const SizedBox(height: Spacing.s2),
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: colors.onCanvasMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
