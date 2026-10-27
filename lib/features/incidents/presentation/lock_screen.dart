import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
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
    final fold = AppFold.of(context);
    // A cover screen is about square and too narrow for the clock beside
    // the cards, so it keeps the upright column and scrolls.
    final isWide = (size.isExpanded || size.isShort) && !size.isCover;

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

                // A half-open foldable: the clock holds still on one side
                // of the fold and the cards scroll on the other.
                if (!fold.isNone)
                  _FoldedLockScreen(state: state)
                else
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
                                    // A pinned action keeps a phone's
                                    // width on a tablet or a desktop.
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: size.isCompact
                                              ? double.infinity
                                              : AppSize.actionMaxWidth,
                                        ),
                                        child: AppButton(
                                          label: LocaleKeys
                                              .lock_screen_open_button
                                              .tr(),
                                          variant: AppButtonVariant.ghost,
                                          isFullWidth: true,
                                          onPressed: () => _leave(context),
                                        ),
                                      ),
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

/// Back to where the lock screen was opened from, or Home.
void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

/// The lock screen on a half-open foldable. Book: the clock in the start
/// pane, the cards and Open in the end pane. Tabletop: the clock in the top
/// half, the cards and Open in the bottom half. Nothing sits on the fold.
class _FoldedLockScreen extends StatelessWidget {
  const _FoldedLockScreen({required this.state});

  final LockScreenState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppFoldSplit(
      stage: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              leading: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.lock_screen_back_aria_label.tr(),
                onPressed: () => _leave(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _clockBlock(
                    state,
                    colors,
                    CrossAxisAlignment.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Built in its own pane, so a wide tabletop half caps the cards at
      // a column's width and Open at a phone's.
      body: Builder(
        builder: (context) {
          final isCompact = AppSize.of(context).isCompact;
          Widget capped(double width, Widget child) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? double.infinity : width,
              ),
              child: child,
            ),
          );
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, Spacing.s4, 16, 0),
                    child: capped(
                      AppSize.contentMaxWidth,
                      _notificationCards(state, context),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, Spacing.s3, 16, 16),
                  child: capped(
                    AppSize.actionMaxWidth,
                    AppButton(
                      label: LocaleKeys.lock_screen_open_button.tr(),
                      variant: AppButtonVariant.ghost,
                      isFullWidth: true,
                      onPressed: () => _leave(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
