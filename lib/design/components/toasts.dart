import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

enum AppToastVariant {
  normal,
  crit,
  ack,
}

/// Floating pill toast with 32px face and message text.
class AppToast extends StatelessWidget {
  const AppToast({
    this.message,
    this.boldText,
    this.boldTextSuffix,
    this.child,
    this.variant = AppToastVariant.normal,
    this.faceState,
    super.key,
  });

  final String? message;
  final String? boldText;
  final String? boldTextSuffix;
  final Widget? child;
  final AppToastVariant variant;
  final FaceState? faceState;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final resolvedFace =
        faceState ??
        switch (variant) {
          AppToastVariant.normal => FaceState.calm,
          AppToastVariant.crit => FaceState.alarmed,
          AppToastVariant.ack => FaceState.acked,
        };

    final stroke = switch (variant) {
      AppToastVariant.normal => colors.onPanel,
      AppToastVariant.crit => colors.crit,
      AppToastVariant.ack => colors.cobaltOnDark,
    };

    Widget content;
    if (child != null) {
      content = child!;
    } else {
      content = RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.onPanel,
          ),
          children: [
            if (message != null) TextSpan(text: message),
            if (boldText != null) ...[
              if (message != null) const TextSpan(text: ' '),
              TextSpan(
                text: boldText,
                style: TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontFamilyFallback: AppTypography.fontMonoFallbacks,
                  fontWeight: FontWeight.w700,
                  color: colors.onPanel,
                ),
              ),
            ],
            if (boldTextSuffix != null) TextSpan(text: ' $boldTextSuffix'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.fullAll,
        boxShadow: AppShadows.lg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaceWidget(
            state: resolvedFace,
            size: 32,
            overrideFillColor: colors.panel,
            overrideStrokeColor: stroke,
            overrideInkColor: colors.onPanel,
          ),
          const SizedBox(width: 12),
          Flexible(child: content),
        ],
      ),
    );
  }
}
