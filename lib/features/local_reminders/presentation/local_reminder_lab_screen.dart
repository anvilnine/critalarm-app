import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_lab_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_lab_state.dart';
import 'package:critalarm/features/local_reminders/presentation/widgets/local_reminders_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Developer options > Reminder lab. Same build gating as the rest of that
/// screen: only a developer build shows the row that leads here.
class LocalReminderLabScreen extends StatelessWidget {
  const LocalReminderLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<LocalReminderLabCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _LocalReminderLabContent(),
    );
  }
}

class _LocalReminderLabContent extends StatelessWidget {
  const _LocalReminderLabContent();

  static final DateFormat _when = DateFormat('EEE d MMM HH:mm');

  static String kindLabel(LocalReminderKind? kind) => switch (kind) {
    LocalReminderKind.fireDrill =>
      LocaleKeys.local_reminders_kind_fire_drill.tr(),
    LocalReminderKind.silentTopic =>
      LocaleKeys.local_reminders_kind_silent_topic.tr(),
    LocalReminderKind.backup => LocaleKeys.local_reminders_kind_backup.tr(),
    LocalReminderKind.planHeadsUp =>
      LocaleKeys.local_reminders_kind_plan_heads_up.tr(),
    LocalReminderKind.morningAfter =>
      LocaleKeys.local_reminders_kind_morning_after.tr(),
    LocalReminderKind.proLater =>
      LocaleKeys.local_reminders_kind_pro_later.tr(),
    LocalReminderKind.reviewAsk =>
      LocaleKeys.local_reminders_kind_review_ask.tr(),
    LocalReminderKind.feedbackAsk =>
      LocaleKeys.local_reminders_kind_feedback_ask.tr(),
    null => '?',
  };

  static String _onOff(bool isOn) => isOn
      ? LocaleKeys.local_reminders_lab_on.tr()
      : LocaleKeys.local_reminders_lab_off.tr();

  static String _time(DateTime? at) =>
      at == null ? LocaleKeys.local_reminders_lab_never.tr() : _when.format(at);

  Widget _info(BuildContext context, String name, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppListRow(name: name, meta: value, faceState: null),
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalReminderLabCubit, LocalReminderLabState>(
      builder: (context, state) {
        final cubit = context.read<LocalReminderLabCubit>();
        final spent = state.budgetSpentAt;

        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.local_reminders_lab_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings/developer');
                }
              },
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSectionHeader(
                        LocaleKeys.local_reminders_lab_now_header.tr(),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_switch_reminders_title.tr(),
                        _onOff(state.switches.reminders),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_switch_offers_title.tr(),
                        _onOff(state.switches.offers),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_lab_system.tr(),
                        state.notificationsAllowed
                            ? LocaleKeys.local_reminders_lab_allowed.tr()
                            : LocaleKeys.local_reminders_lab_blocked.tr(),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_lab_budget.tr(),
                        spent == null
                            ? LocaleKeys.local_reminders_lab_budget_free.tr()
                            : LocaleKeys.local_reminders_lab_budget_used.tr(
                                namedArgs: {
                                  'used': _when.format(spent),
                                  'free': _when.format(
                                    spent.add(const Duration(days: 7)),
                                  ),
                                },
                              ),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_lab_pro.tr(),
                        LocaleKeys.local_reminders_lab_pro_value.tr(
                          namedArgs: {
                            'asked': _time(state.proAskedAt),
                            'count': '${state.proDismissCount}',
                          },
                        ),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_lab_review.tr(),
                        LocaleKeys.local_reminders_lab_review_value.tr(
                          namedArgs: {
                            'asked': _time(state.reviewAskedAt),
                            'count': '${state.reviewAskCount}',
                          },
                        ),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_lab_feedback.tr(),
                        _time(state.feedbackAskedAt),
                      ),
                      _info(
                        context,
                        LocaleKeys.local_reminders_lab_tz.tr(),
                        state.timeZone,
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.local_reminders_lab_scheduled_header.tr(
                          namedArgs: {'count': '${state.pending.length}'},
                        ),
                      ),
                      if (state.pending.isEmpty)
                        _info(
                          context,
                          LocaleKeys.local_reminders_lab_scheduled_empty.tr(),
                          '',
                        ),
                      for (final reminder in state.pending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppListRow(
                            name:
                                '${kindLabel(reminder.kind)} · '
                                '${reminder.id}',
                            meta: _time(reminder.fireAt),
                            faceState: null,
                            trailing: AppButton(
                              label: LocaleKeys.local_reminders_lab_cancel.tr(),
                              size: AppButtonSize.sm,
                              variant: AppButtonVariant.ghost,
                              onPressed: () =>
                                  unawaited(cubit.cancel(reminder.id)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.local_reminders_lab_fire_header.tr(),
                      ),
                      for (final kind in LocalReminderKind.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppListRow(
                            name: kindLabel(kind),
                            meta: '',
                            faceState: null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppButton(
                                  label: LocaleKeys.local_reminders_lab_in_ten
                                      .tr(),
                                  size: AppButtonSize.sm,
                                  variant: AppButtonVariant.ghost,
                                  onPressed: () => unawaited(
                                    cubit.fire(
                                      kind,
                                      delay: const Duration(seconds: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AppButton(
                                  label: LocaleKeys.local_reminders_lab_now
                                      .tr(),
                                  size: AppButtonSize.sm,
                                  onPressed: () => unawaited(
                                    cubit.fire(kind, delay: Duration.zero),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      AppToggleRow(
                        title: LocaleKeys.local_reminders_lab_skip_rules.tr(),
                        subtitle: LocaleKeys
                            .local_reminders_lab_skip_rules_subtitle
                            .tr(),
                        value: state.skipRules,
                        onChanged: (value) =>
                            unawaited(cubit.setSkipRules(skip: value)),
                      ),
                      const SizedBox(height: 8),
                      AppListRow(
                        name: LocaleKeys.local_reminders_lab_show_sheet.tr(),
                        meta: '',
                        faceState: null,
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: context.appColors.ink3,
                          size: 16,
                        ),
                        onTap: () => unawaited(
                          showLocalRemindersSheet(
                            context: context,
                            store: getIt<LocalReminderStore>(),
                            isSelfHosted: state.isSelfHosted,
                            onAnswered: getIt<LocalReminderPlanTrigger>().run,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: LocaleKeys.local_reminders_lab_reset.tr(),
                        variant: AppButtonVariant.crit,
                        isFullWidth: true,
                        onPressed: () => unawaited(cubit.resetAll()),
                      ),
                      const SizedBox(height: 14),
                      AppSectionHeader(
                        LocaleKeys.local_reminders_lab_pool_header.tr(),
                      ),
                      for (final line in cubit.poolPreview())
                        _info(context, line.title, line.body),
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
