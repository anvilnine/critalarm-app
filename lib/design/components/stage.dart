import 'package:critalarm/design/components/skeleton.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
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
    this.wordFontSize,
    this.topicName,
    this.sub,
    this.padding = const EdgeInsets.fromLTRB(24, Spacing.s4, 24, 0),
    this.faceWidget,
    this.isHorizontal = false,
    this.idleWhenCalm = false,
    this.isLoading = false,
    super.key,
  }) : subWidget = null;

  /// Horizontal stage matching index.html Settings mockup:
  /// 56px face aligned with subtext in a row.
  const AppStage.horizontal({
    required this.faceState,
    this.faceSize = 56.0,
    this.sub,
    this.subWidget,
    this.isLive = false,
    this.padding = const EdgeInsets.fromLTRB(24, Spacing.s3, 24, 0),
    this.faceWidget,
    this.isLoading = false,
    super.key,
  }) : word = null,
       wordIsBig = false,
       wordFontSize = null,
       topicName = null,
       isHorizontal = true,
       idleWhenCalm = false;

  final FaceState? faceState;
  final double faceSize;
  final bool isLive;
  final String? word;
  final bool wordIsBig;
  final double? wordFontSize;
  final String? topicName;
  final String? sub;
  final EdgeInsetsGeometry padding;
  final Widget? faceWidget;
  final bool isHorizontal;

  /// True lets a calm face play the small idle expressions while nothing is
  /// happening. Any other face means something real and is left alone.
  final bool idleWhenCalm;

  /// True shows animated skeleton bones for words/subtext while stage content
  /// is loading.
  final bool isLoading;

  /// Horizontal stage only: shown in place of [sub], for a line that moves.
  /// Style it with [horizontalSubStyle] so it matches.
  final Widget? subWidget;

  /// The style of the line beside the face in a horizontal stage.
  static TextStyle horizontalSubStyle(AppColors colors) => TextStyle(
    fontFamily: AppTypography.fontBody,
    fontFamilyFallback: AppTypography.fontBodyFallbacks,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    color: colors.onCanvasMuted,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isShort = AppSize.of(context).isShort;

    if (isHorizontal) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            if (faceWidget != null)
              faceWidget!
            else if (faceState != null)
              stageFace(
                context,
                state: faceState!,
                size: faceSize,
                isLive: isLive,
              ),
            if (subWidget != null || sub != null || isLoading) ...[
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedSize(
                  duration: context.motion(AppDurations.base),
                  curve: AppCurves.easeOut,
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: context.motion(AppDurations.base),
                    switchInCurve: AppCurves.easeOut,
                    switchOutCurve: AppCurves.easeOut,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: isLoading
                        ? const KeyedSubtree(
                            key: ValueKey('stage_horizontal_skeleton'),
                            child: AppSkeleton(
                              child: AppSkeletonBone(
                                width: 120,
                                height: 16,
                                borderRadius: Radii.xsAll,
                              ),
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey('stage_horizontal_content_$sub'),
                            child:
                                subWidget ??
                                Text(
                                  sub ?? '',
                                  style: horizontalSubStyle(colors),
                                ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final resolvedFontSize = wordFontSize ?? (wordIsBig ? 56.0 : 44.0);

    if (isShort) {
      // A short display has no room to stand the face above the words,
      // so the face sits beside them instead.
      return Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faceWidget != null)
              faceWidget!
            else if (faceState != null)
              stageFace(
                context,
                state: faceState!,
                size: faceSize.clamp(0.0, 96.0),
                isLive: isLive,
                idleWhenCalm: idleWhenCalm,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedSize(
                duration: context.motion(AppDurations.base),
                curve: AppCurves.easeOut,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: context.motion(AppDurations.base),
                  switchInCurve: AppCurves.easeOut,
                  switchOutCurve: AppCurves.easeOut,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: isLoading
                      ? KeyedSubtree(
                          key: const ValueKey('stage_short_skeleton'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppSkeleton(
                                child: AppSkeletonBone(
                                  width: 110,
                                  height: resolvedFontSize * 0.55,
                                  borderRadius: Radii.smAll,
                                ),
                              ),
                              if (topicName != null &&
                                  topicName!.isNotEmpty) ...[
                                const SizedBox(height: Spacing.s3),
                                _buildTopicName(colors, TextAlign.left),
                              ],
                              const SizedBox(height: Spacing.s2),
                              const AppSkeleton(
                                child: AppSkeletonBone(
                                  width: 90,
                                  height: 14,
                                  borderRadius: Radii.xsAll,
                                ),
                              ),
                            ],
                          ),
                        )
                      : KeyedSubtree(
                          key: ValueKey('stage_short_content_${word}_$sub'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (word != null && word!.isNotEmpty)
                                _buildWord(
                                  colors,
                                  resolvedFontSize * 0.7,
                                  TextAlign.left,
                                ),
                              if (topicName != null &&
                                  topicName!.isNotEmpty) ...[
                                const SizedBox(height: Spacing.s3),
                                _buildTopicName(colors, TextAlign.left),
                              ],
                              if (sub != null && sub!.isNotEmpty) ...[
                                const SizedBox(height: Spacing.s2),
                                _buildSub(colors, TextAlign.left),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (faceWidget != null)
            faceWidget!
          else if (faceState != null)
            stageFace(
              context,
              state: faceState!,
              size: faceSize,
              isLive: isLive,
              idleWhenCalm: idleWhenCalm,
            ),
          AnimatedSize(
            duration: context.motion(AppDurations.base),
            curve: AppCurves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: context.motion(AppDurations.base),
              switchInCurve: AppCurves.easeOut,
              switchOutCurve: AppCurves.easeOut,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: isLoading
                  ? KeyedSubtree(
                      key: const ValueKey('stage_vertical_skeleton'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: faceSize > 120 ? Spacing.s5 : Spacing.s3,
                          ),
                          AppSkeleton(
                            child: AppSkeletonBone(
                              width: 140,
                              height: resolvedFontSize * 0.8,
                              borderRadius: Radii.smAll,
                            ),
                          ),
                          if (topicName != null && topicName!.isNotEmpty) ...[
                            const SizedBox(height: Spacing.s3),
                            _buildTopicName(colors, TextAlign.center),
                          ],
                          const SizedBox(height: Spacing.s2),
                          const AppSkeleton(
                            child: AppSkeletonBone(
                              width: 110,
                              height: 16,
                              borderRadius: Radii.xsAll,
                            ),
                          ),
                        ],
                      ),
                    )
                  : KeyedSubtree(
                      key: ValueKey('stage_vertical_content_${word}_$sub'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (word != null && word!.isNotEmpty) ...[
                            SizedBox(
                              height: faceSize > 120 ? Spacing.s5 : Spacing.s3,
                            ),
                            _buildWord(
                              colors,
                              resolvedFontSize,
                              TextAlign.center,
                            ),
                          ],
                          if (topicName != null && topicName!.isNotEmpty) ...[
                            const SizedBox(height: Spacing.s3),
                            _buildTopicName(colors, TextAlign.center),
                          ],
                          if (sub != null && sub!.isNotEmpty) ...[
                            const SizedBox(height: Spacing.s2),
                            _buildSub(colors, TextAlign.center),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWord(AppColors colors, double fontSize, TextAlign align) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        word!,
        textAlign: align,
        style: TextStyle(
          fontFamily: AppTypography.fontDisplay,
          fontFamilyFallback: AppTypography.fontDisplayFallbacks,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: -0.04 * fontSize,
          height: 1,
          color: colors.onCanvas,
        ),
      ),
    );
  }

  Widget _buildTopicName(AppColors colors, TextAlign align) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        topicName!,
        textAlign: align,
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: colors.onCanvas,
        ),
      ),
    );
  }

  Widget _buildSub(AppColors colors, TextAlign align) {
    return Text(
      sub!,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: colors.onCanvasMuted,
      ),
    );
  }
}
