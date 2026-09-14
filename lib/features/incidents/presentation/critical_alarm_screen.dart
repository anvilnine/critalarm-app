import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
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
    return BlocConsumer<CriticalAlarmCubit, CriticalAlarmState>(
      listenWhen: (previous, current) =>
          !previous.isAcknowledged && current.isAcknowledged,
      listener: (context, state) => AppHaptics.success(),
      builder: (context, state) {
        return SeverityScope(
          mode: state.severityMode,
          child: Builder(
            builder: (context) {
              final colors = context.appColors;
              return state.isAcknowledged
                  ? _AcknowledgedScreen(state: state, colors: colors)
                  : _RingingScreen(state: state, colors: colors);
            },
          ),
        );
      },
    );
  }
}

/// The ringing takeover: pulse rings, face, incident detail, and the two
/// pinned actions (acknowledge and snooze).
class _RingingScreen extends StatelessWidget {
  const _RingingScreen({required this.state, required this.colors});

  final CriticalAlarmState state;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      hasTabBar: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s6, 16, 0),
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
                        const PulseRingWidget(size: 264),
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
                    style: AppTypography.display(colors.onCanvas),
                  ),
                ),
                const SizedBox(height: Spacing.s2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    state.topic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontMono,
                      fontFamilyFallback: AppTypography.fontMonoFallbacks,
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
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.onCanvas,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s4, 16, 16),
            child: AppSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    state.title,
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
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
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 14,
                      color: colors.ink2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.meta,
                    style: TextStyle(
                      fontFamily: AppTypography.fontMono,
                      fontFamilyFallback: AppTypography.fontMonoFallbacks,
                      fontSize: 12,
                      color: colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: AppButton(
              label: LocaleKeys.critical_alarm_acknowledge_button.tr(),
              isFullWidth: true,
              isLoading: state.isAcknowledging,
              onPressed: () {
                unawaited(context.read<CriticalAlarmCubit>().acknowledge());
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: AppButton(
              label: LocaleKeys.critical_alarm_snooze_button.tr(),
              variant: AppButtonVariant.ghost,
              isFullWidth: true,
              // Snooze has no cubit method yet, so the press only confirms
              // itself with a haptic until one exists.
              onPressed: AppHaptics.capture,
            ),
          ),
        ],
      ),
    );
  }
}

/// The acknowledged confirmation: how long it rang, when it started and was
/// acknowledged, where it came from, and the two pinned exits.
class _AcknowledgedScreen extends StatelessWidget {
  const _AcknowledgedScreen({required this.state, required this.colors});

  final CriticalAlarmState state;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final incident = state.incident;
    final startedAt = incident?.openedAt;
    final ackedAt = incident?.ackedAt;
    final ringDuration = (startedAt != null && ackedAt != null)
        ? ackedAt.difference(startedAt)
        : const Duration(minutes: 2, seconds: 14);
    final startedLabel = startedAt != null
        ? _formatClock(startedAt)
        : '03:12:04';
    final ackedLabel = ackedAt != null ? _formatClock(ackedAt) : '03:14:22';

    return AppScreenScaffold(
      hasTabBar: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s6, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaceWidget(state: state.faceState, size: 224),
                const SizedBox(height: Spacing.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    LocaleKeys.critical_alarm_acked_title.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.display(colors.onCanvas),
                  ),
                ),
                const SizedBox(height: Spacing.s2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    state.topic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontMono,
                      fontFamilyFallback: AppTypography.fontMonoFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: colors.onCanvas,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s2),
                Text(
                  LocaleKeys.critical_alarm_acked_sub.tr(
                    namedArgs: {
                      'duration': _formatRingDuration(ringDuration),
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.onCanvas,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s4, 16, 16),
            child: AppSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppKeyValueRow(
                    label: LocaleKeys.critical_alarm_started_label.tr(),
                    value: startedLabel,
                  ),
                  const SizedBox(height: 8),
                  AppKeyValueRow(
                    label: LocaleKeys.critical_alarm_acknowledged_label.tr(),
                    value: ackedLabel,
                  ),
                  const SizedBox(height: 8),
                  AppKeyValueRow(
                    label: LocaleKeys.critical_alarm_source_label.tr(),
                    value: state.meta,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: AppButton(
              label: LocaleKeys.critical_alarm_open_topic_button.tr(
                namedArgs: {'topic': state.topic},
              ),
              isFullWidth: true,
              onPressed: () {
                AppHaptics.capture();
                context.go('/topics/${state.topic}');
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: AppButton(
              label: LocaleKeys.critical_alarm_back_to_topics_button.tr(),
              variant: AppButtonVariant.ghost,
              isFullWidth: true,
              onPressed: () {
                AppHaptics.capture();
                context.go('/');
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final second = dt.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatRingDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes min $seconds s';
}
