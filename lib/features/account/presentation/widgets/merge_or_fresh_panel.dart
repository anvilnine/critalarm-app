import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Keep both, or start fresh.
///
/// Both counts come from the server, which counted them on this phone's
/// account: the one that is folded in or given up. Neither button is the
/// default and neither is dressed up as the safe one, and each takes one tap,
/// because this screen is the confirmation.
class MergeOrFreshPanel extends StatelessWidget {
  const MergeOrFreshPanel({required this.state, super.key});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final colors = context.appColors;
    final choice = state.choice!;

    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.account_choose_title.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontFamilyFallback: AppTypography.fontDisplayFallbacks,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.account_choose_body.tr(
              namedArgs: {
                'topics': LocaleKeys.account_choose_topics.plural(
                  choice.topics,
                ),
                'incidents': LocaleKeys.account_choose_incidents.plural(
                  choice.incidents,
                ),
              },
            ),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 14,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          if (state.liveIncidentId != null) ...[
            const SizedBox(height: 12),
            _LiveIncident(incidentId: state.liveIncidentId!),
          ],
          const SizedBox(height: 16),
          _Choice(
            title: LocaleKeys.account_keep_both_title.tr(),
            body: LocaleKeys.account_keep_both_body.tr(),
            button: LocaleKeys.account_keep_both_button.tr(),
            variant: AppButtonVariant.paper,
            isLoading: state.isBusy,
            onPressed: () => unawaited(cubit.keepBoth()),
          ),
          const SizedBox(height: 12),
          _Choice(
            title: LocaleKeys.account_start_fresh_title.tr(),
            body: LocaleKeys.account_start_fresh_body.tr(),
            // The part a person cannot guess, on screen before the call is
            // made rather than after it.
            warning: LocaleKeys.account_start_fresh_tokens.plural(
              choice.topics,
            ),
            button: LocaleKeys.account_start_fresh_button.tr(),
            variant: AppButtonVariant.crit,
            isLoading: state.isBusy,
            onPressed: () => unawaited(cubit.startFresh()),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.body,
    required this.button,
    required this.variant,
    required this.isLoading,
    required this.onPressed,
    this.warning,
  });

  final String title;
  final String body;
  final String? warning;
  final String button;
  final AppButtonVariant variant;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          if (warning != null) ...[
            const SizedBox(height: 6),
            Text(
              warning!,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.crit,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          AppButton(
            label: button,
            size: AppButtonSize.sm,
            variant: variant,
            isFullWidth: true,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _LiveIncident extends StatelessWidget {
  const _LiveIncident({required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.account_live_incident_title.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.crit,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.account_live_incident_body.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 13,
              color: colors.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.account_live_incident_button.tr(),
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: () => context.push('/incidents/$incidentId'),
          ),
        ],
      ),
    );
  }
}
