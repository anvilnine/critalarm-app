import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Critical Alarm takeover screen matching docs/design-system/index.html.
class CriticalAlarmScreen extends StatelessWidget {
  const CriticalAlarmScreen({this.incidentId, super.key});

  final String? incidentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<CriticalAlarmCubit>();
        unawaited(cubit.load(incidentId: incidentId));
        return cubit;
      },
      child: const _CriticalAlarmView(),
    );
  }
}

class _CriticalAlarmView extends StatelessWidget {
  const _CriticalAlarmView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CriticalAlarmCubit, CriticalAlarmState>(
      builder: (context, state) {
        return SeverityScope(
          mode: state.severityMode,
          child: Builder(
            builder: (context) {
              final colors = context.appColors;

              return Scaffold(
                backgroundColor: colors.canvas,
                body: GhostField(
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
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
                                      ariaLabel: 'Back',
                                      onPressed: () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/');
                                        }
                                      },
                                    ),
                                    trailing: state.isAcknowledged
                                        ? AppToast(
                                            variant: AppToastVariant.ack,
                                            message:
                                                state.feedbackMessage ??
                                                'Acknowledged at 03:14 by Z',
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: Spacing.s2),

                                  // Stage
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: SizedBox(
                                            width: 264,
                                            height: 264,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              clipBehavior: Clip.none,
                                              children: [
                                                if (!state.isAcknowledged)
                                                  const PulseRingWidget(
                                                    size: 264,
                                                  ),
                                                FaceWidget(
                                                  state: state.faceState,
                                                  size: 264,
                                                  isLive: state.isLive,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: Spacing.s4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            state.word,
                                            textAlign: TextAlign.center,
                                            style: AppTypography.display(
                                              colors.onCanvas,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: Spacing.s2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            state.topic,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.fontMono,
                                              fontFamilyFallback: AppTypography
                                                  .fontMonoFallbacks,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17,
                                              color: colors.onCanvas,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: Spacing.s2),
                                        Text(
                                          state.subtext,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontBody,
                                            fontFamilyFallback:
                                                AppTypography.fontBodyFallbacks,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: colors.onCanvas,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // Floating AppSheet
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      Spacing.s4,
                                      16,
                                      16 + MediaQuery.paddingOf(context).bottom,
                                    ),
                                    child: AppSheet(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            state.title,
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.fontDisplay,
                                              fontFamilyFallback: AppTypography
                                                  .fontDisplayFallbacks,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 22,
                                              color: colors.ink,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            state.body,
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.fontBody,
                                              fontFamilyFallback: AppTypography
                                                  .fontBodyFallbacks,
                                              fontSize: 14,
                                              color: colors.ink2,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            state.meta,
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTypography.fontMono,
                                              fontFamilyFallback: AppTypography
                                                  .fontMonoFallbacks,
                                              fontSize: 12,
                                              color: colors.ink3,
                                            ),
                                          ),
                                          const SizedBox(height: Spacing.s4),
                                          AppButton(
                                            label: state.isAcknowledged
                                                ? 'Dismiss'
                                                : 'Acknowledge',
                                            size: AppButtonSize.lg,
                                            isFullWidth: true,
                                            isLoading: state.isAcknowledging,
                                            onPressed: () {
                                              if (state.isAcknowledged) {
                                                if (context.canPop()) {
                                                  context.pop();
                                                } else {
                                                  context.go('/');
                                                }
                                              } else {
                                                unawaited(
                                                  context
                                                      .read<
                                                        CriticalAlarmCubit
                                                      >()
                                                      .acknowledge(),
                                                );
                                              }
                                            },
                                          ),
                                        ],
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
                ),
              );
            },
          ),
        );
      },
    );
  }
}
