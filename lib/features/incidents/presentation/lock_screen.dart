import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What sits faintly behind the lock screen.
enum LockWatermark {
  /// A yellow head with its ink features, faded back.
  yellowFace,

  /// An abstract shape from the ambient set. No face.
  shape,
}

/// Which watermark the lock screen ships with. The one place to switch it.
const LockWatermark lockScreenWatermark = LockWatermark.yellowFace;

/// Lock Screen mockup matching docs/design-system/index.html.
class LockScreen extends StatelessWidget {
  const LockScreen({this.watermark = lockScreenWatermark, super.key});

  final LockWatermark watermark;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<LockScreenCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: _LockScreenView(watermark: watermark),
    );
  }
}

class _LockScreenView extends StatelessWidget {
  const _LockScreenView({required this.watermark});

  final LockWatermark watermark;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = AppSize.of(context);
    final isWide = size.isExpanded || size.isShort;

    return BlocBuilder<LockScreenCubit, LockScreenState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            child: Stack(
              children: [
                // Watermark behind the clock and cards, see [LockWatermark].
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final top = constraints.maxHeight * 0.38 - 260.0;
                      return Stack(
                        children: [
                          Positioned(
                            top: top,
                            left: (constraints.maxWidth - 520.0) / 2.0,
                            child: IgnorePointer(
                              child: switch (watermark) {
                                LockWatermark.yellowFace =>
                                  const GhostWatermarkFace(size: 520),
                                LockWatermark.shape =>
                                  const GhostWatermarkShape(size: 520),
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Foreground content. Only the top is padded for the status
                // bar and back button; the bottom is left open so the
                // notification stack scrolls edge to edge with no clamp.
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTopBar(
                                  // Not in the scaffold's 58, so 8 above the
                                  // 48 box puts the circle where 12 above a
                                  // 40 one did.
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  leading: AppIconButton(
                                    glyph: GlyphType.back,
                                    ariaLabel: LocaleKeys
                                        .lock_screen_back_aria_label
                                        .tr(),
                                    onPressed: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/');
                                      }
                                    },
                                  ),
                                ),

                                if (isWide)
                                  Padding(
                                    // 4 less on top: the bar above is 4
                                    // taller, for its back button's tap box.
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      Spacing.s4 - 4,
                                      16,
                                      0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _clockBlock(
                                            state,
                                            colors,
                                            CrossAxisAlignment.start,
                                          ),
                                        ),
                                        const SizedBox(width: 40),
                                        Expanded(
                                          child: _notificationCards(
                                            state,
                                            context,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else ...[
                                  // Clock section
                                  Padding(
                                    // 4 less on top: the bar above is 4
                                    // taller, for its back button's tap box.
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      Spacing.s4 - 4,
                                      16,
                                      Spacing.s4,
                                    ),
                                    child: _clockBlock(
                                      state,
                                      colors,
                                      CrossAxisAlignment.center,
                                    ),
                                  ),

                                  // Notification cards
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: _notificationCards(state, context),
                                  ),
                                ],

                                const Spacer(),

                                // Dismiss / Open button to return to home
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    Spacing.s3,
                                    16,
                                    16 + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  child: AppButton(
                                    label: LocaleKeys.lock_screen_open_button
                                        .tr(),
                                    variant: AppButtonVariant.ghost,
                                    isFullWidth: true,
                                    onPressed: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/');
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _clockBlock(
  LockScreenState state,
  AppColors colors,
  CrossAxisAlignment align,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: align,
    children: [
      Text(
        state.dateText,
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.onCanvas,
        ),
      ),
      const SizedBox(height: Spacing.s1),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          state.timeText,
          style: AppTypography.display(
            colors.onCanvas,
            fontSize: 96,
          ).copyWith(letterSpacing: -0.05 * 96, height: 0.9),
        ),
      ),
    ],
  );
}

Widget _notificationCards(LockScreenState state, BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (int i = 0; i < state.notifications.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        AppNotificationCard(
          topic: state.notifications[i].topic,
          title: state.notifications[i].title,
          body: state.notifications[i].body,
          faceState: state.notifications[i].faceState,
          ringingPillText: state.notifications[i].ringingPillText,
          timeText: state.notifications[i].timeText,
          isCrit: state.notifications[i].isCrit,
          isQuiet: state.notifications[i].isQuiet,
          onTap: state.notifications[i].isCrit
              ? () {
                  AppHaptics.capture();
                  unawaited(context.push('/alarm'));
                }
              : null,
        ),
      ],
    ],
  );
}
