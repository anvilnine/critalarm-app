import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Lock Screen mockup matching docs/design-system/index.html.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<LockScreenCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _LockScreenView(),
    );
  }
}

class _LockScreenView extends StatelessWidget {
  const _LockScreenView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<LockScreenCubit, LockScreenState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            child: Stack(
              children: [
                // Watermark alarmed face (520px, faint ghost stroke)
                // matching mockup
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
                              child: FaceWidget(
                                state: FaceState.alarmed,
                                size: 520,
                                overrideFillColor: Colors.transparent,
                                overrideStrokeColor: colors.canvasGhostStrong,
                                overrideInkColor: colors.canvasGhostStrong,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Foreground content
                SafeArea(
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

                                // Clock section
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Spacing.s4,
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        state.dateText,
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontBody,
                                          fontFamilyFallback:
                                              AppTypography.fontBodyFallbacks,
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
                                          style:
                                              AppTypography.display(
                                                colors.onCanvas,
                                                fontSize: 96,
                                              ).copyWith(
                                                letterSpacing: -0.05 * 96,
                                                height: 0.9,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Notification cards
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (
                                        int i = 0;
                                        i < state.notifications.length;
                                        i++
                                      ) ...[
                                        if (i > 0) const SizedBox(height: 12),
                                        AppNotificationCard(
                                          topic: state.notifications[i].topic,
                                          title: state.notifications[i].title,
                                          body: state.notifications[i].body,
                                          faceState:
                                              state.notifications[i].faceState,
                                          ringingPillText: state
                                              .notifications[i]
                                              .ringingPillText,
                                          timeText:
                                              state.notifications[i].timeText,
                                          isCrit: state.notifications[i].isCrit,
                                          isQuiet:
                                              state.notifications[i].isQuiet,
                                          onTap: state.notifications[i].isCrit
                                              ? () => context.push('/alarm')
                                              : null,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

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
