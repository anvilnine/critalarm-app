import 'dart:async';

import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/incidents/domain/loudness_ask.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/incidents/presentation/alarm_loudness_screen.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// "Loud enough?" with Yes and No, above the exits of an acknowledged test
/// alarm on an iPhone. [loudnessAskFor] decides when it is drawn.
///
/// Yes takes the question away and the screen goes on as it always does.
/// No opens [AlarmLoudnessScreen]. When that screen comes back with "Ring
/// again", this ends the test on screen, so its desk timer cannot ring it
/// again later as a real alarm, and goes where [retry] says.
class LoudEnoughAsk extends StatefulWidget {
  const LoudEnoughAsk({
    required this.retry,
    required this.setupTest,
    required this.incidentId,
    required this.textColor,
    super.key,
  });

  final LoudnessRetry retry;
  final SetupTestKind setupTest;

  /// The test this question was drawn for.
  final String incidentId;
  final Color textColor;

  @override
  State<LoudEnoughAsk> createState() => _LoudEnoughAskState();
}

class _LoudEnoughAskState extends State<LoudEnoughAsk> {
  bool _isAnswered = false;
  bool _isBusy = false;

  Future<void> _no() async {
    if (_isBusy) return;
    AppHaptics.capture();
    final router = GoRouter.of(context);
    final answer = await router.pushNamed<bool>(AppRoute.alarmLoudness);
    if (!mounted || answer != alarmLoudnessRingAgain) return;
    setState(() => _isBusy = true);
    try {
      await _ringAgain(router, context.read<CriticalAlarmCubit>());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _ringAgain(GoRouter router, CriticalAlarmCubit cubit) async {
    final id = widget.incidentId;
    // A real alarm took the screen over while Settings was open. It stays,
    // and nothing is closed.
    if (cubit.state.incident?.id != id) return;
    switch (widget.retry) {
      case LoudnessRetry.setupStep:
        // The phone-only test has nothing on a server to close.
        final mayGo =
            widget.setupTest != SetupTestKind.serverSent ||
            await cubit.closeSetupTests(id);
        final route = OnboardingStepRegistry.entryFor(
          OnboardingStepId.realRing,
        )?.route;
        if (mayGo && route != null) router.go(route);
      case LoudnessRetry.testRing:
        final isServerTest = id != phoneOnlyTestIncidentId;
        if (isServerTest && cubit.state.status != CriticalAlarmStatus.closed) {
          await cubit.closeIncident();
        }
        if (cubit.state.incident?.id != id) return;
        router.goNamed(AppRoute.testRing);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnswered) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              LocaleKeys.alarm_loudness_ask.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                widget.textColor,
                fontSize: 17,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: Spacing.s2),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: LocaleKeys.alarm_loudness_ask_yes.tr(),
                  variant: AppButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: _isBusy
                      ? null
                      : () {
                          AppHaptics.capture();
                          setState(() => _isAnswered = true);
                        },
                ),
              ),
              const SizedBox(width: Spacing.s2),
              Expanded(
                child: AppButton(
                  label: LocaleKeys.alarm_loudness_ask_no.tr(),
                  variant: AppButtonVariant.ghost,
                  isFullWidth: true,
                  isLoading: _isBusy,
                  onPressed: () => unawaited(_no()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
