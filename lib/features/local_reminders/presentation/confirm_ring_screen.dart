import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/local_reminders/domain/ring_failure.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/confirm_ring_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/confirm_ring_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// "Test ring": pick a topic, then one tap sends `POST /v1/test`.
class ConfirmRingScreen extends StatelessWidget {
  const ConfirmRingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<ConfirmRingCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _ConfirmRingContent(),
    );
  }
}

class _ConfirmRingContent extends StatelessWidget {
  const _ConfirmRingContent();

  static String _lastTest(int? days) {
    if (days == null) return LocaleKeys.local_reminders_ring_never_tested.tr();
    if (days == 0) return LocaleKeys.local_reminders_ring_last_test_today.tr();
    return LocaleKeys.local_reminders_ring_last_test.plural(days);
  }

  static String _failureText(RingFailure failure) => switch (failure) {
    RingFailure.notCritical =>
      LocaleKeys.local_reminders_ring_error_not_critical.tr(),
    RingFailure.unauthorized =>
      LocaleKeys.local_reminders_ring_error_unauthorized.tr(),
    RingFailure.offline => LocaleKeys.local_reminders_ring_error_offline.tr(),
    RingFailure.other => LocaleKeys.local_reminders_ring_error_other.tr(),
  };

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Widget _row(
    BuildContext context,
    ConfirmRingCubit cubit,
    ConfirmRingState state,
    RingTopicRow row,
  ) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppListRow(
        name: row.name,
        meta: _lastTest(row.daysSinceTest),
        faceState: null,
        isSelected: row.name == state.selected,
        trailing: row.name == state.selected
            ? AppGlyph(GlyphType.check, color: colors.cobalt, size: 16)
            : null,
        onTap: () => cubit.select(row.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfirmRingCubit, ConfirmRingState>(
      builder: (context, state) {
        final colors = context.appColors;
        final cubit = context.read<ConfirmRingCubit>();
        final selected = state.selected;
        final didFail = state.status == ConfirmRingStatus.loadFailed;
        final isEmpty =
            state.status != ConfirmRingStatus.loading &&
            state.critical.isEmpty &&
            state.normal.isEmpty;

        return AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.local_reminders_ring_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.close,
              ariaLabel: LocaleKeys.local_reminders_ring_close_aria.tr(),
              onPressed: () => _close(context),
            ),
          ),
          bottomBar: isEmpty || selected == null
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.failure case final failure?) ...[
                      Text(
                        _failureText(failure),
                        textAlign: TextAlign.center,
                        style: AppTypography.small(colors.crit),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (state.status == ConfirmRingStatus.sent) ...[
                      Text(
                        LocaleKeys.local_reminders_ring_sent.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.small(colors.ink2),
                      ),
                      const SizedBox(height: 8),
                    ],
                    AppButton(
                      label: state.isSelectedCritical
                          ? LocaleKeys.local_reminders_ring_button.tr(
                              namedArgs: {'topic': selected},
                            )
                          : LocaleKeys.local_reminders_ring_send_test.tr(),
                      variant: AppButtonVariant.crit,
                      isFullWidth: true,
                      isLoading: state.status == ConfirmRingStatus.sending,
                      onPressed: state.status == ConfirmRingStatus.sent
                          ? null
                          : () => unawaited(cubit.send()),
                    ),
                  ],
                ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
              sliver: SliverToBoxAdapter(
                child: isEmpty
                    ? AppEmptyState(
                        title: didFail
                            ? LocaleKeys.local_reminders_ring_load_failed_title
                                  .tr()
                            : LocaleKeys.local_reminders_ring_empty_title.tr(),
                        description: didFail
                            ? LocaleKeys.local_reminders_ring_error_offline.tr()
                            : LocaleKeys.local_reminders_ring_empty_body.tr(),
                        buttonLabel: null,
                        faceState: FaceState.calm,
                        isLive: false,
                      )
                    : AppSheet(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSectionHeader(
                              LocaleKeys.local_reminders_ring_critical_header
                                  .tr(),
                            ),
                            for (final row in state.critical)
                              _row(context, cubit, state, row),
                            if (state.normal.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              AppSectionHeader(
                                LocaleKeys.local_reminders_ring_normal_header
                                    .tr(),
                              ),
                              for (final row in state.normal)
                                _row(context, cubit, state, row),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              LocaleKeys.local_reminders_ring_note.tr(),
                              style: AppTypography.small(
                                colors.ink3,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
