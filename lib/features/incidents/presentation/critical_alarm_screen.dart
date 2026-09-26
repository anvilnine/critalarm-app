import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/reminders/domain/after_ack_decider.dart';
import 'package:critalarm/features/reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/presentation/widgets/reminder_ask_sheets.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
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

class _CriticalAlarmView extends StatefulWidget {
  const _CriticalAlarmView();

  @override
  State<_CriticalAlarmView> createState() => _CriticalAlarmViewState();
}

class _CriticalAlarmViewState extends State<_CriticalAlarmView> {
  AmbientDirection _direction = AmbientDirection.push;

  /// The alarm just stopped, which is the moment the app proved it works.
  /// Waits for the acknowledged screen to settle, then lets
  /// `AfterAckDecider` pick at most one follow-up: the Reminders sheet after
  /// the first test alarm, the Pro sheet, or nothing now because it is the
  /// middle of the night.
  Future<void> _afterAck(CriticalAlarmState state) async {
    // Read now, used after the wait: another incident can land in those
    // 1.5 seconds, and a sheet must not open over it.
    final cubit = context.read<CriticalAlarmCubit>();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final store = getIt<ReminderStore>();
    final notices = getIt<InAppNoticeRepository>();
    final incident = state.incident;
    // A delivered review or feedback reminder counts as an ask before the
    // Pro rules read the ask times.
    await getIt<ReminderSettler>().settleAsks(now: DateTime.now());
    final proShouldAsk = await getIt<ProAskRules>().shouldAsk();
    final now = DateTime.now();
    final lastSheet = notices.getAfterAckSheetShownAt();
    final next = AfterAckDecider.decide(
      isSetupDone: await getIt<SetupGate>().isDone(),
      ackedAt: now,
      isTestAck: incident == null || IncidentKinds.isTest(incident),
      isRemindersSheetShown: store.readSheetShown(),
      isWeb: kIsWeb,
      offersOn: store.readSwitches().offers,
      proShouldAsk: proShouldAsk,
      hasOtherOpenIncident: cubit.state.openIncidents.isNotEmpty,
      alreadyShownToday: lastSheet != null && _sameDay(lastSheet, now),
    );
    // Stamped before the sheet opens, so the second ack of the same day gets
    // nothing whichever of the two was shown.
    if (next == AfterAck.remindersSheet || next == AfterAck.proSheet) {
      await notices.markAfterAckSheetShown();
    }
    // Only the two sheets need this screen. Planning the morning after and
    // owing the Pro sheet happen even if the user already left it.
    switch (next) {
      case AfterAck.remindersSheet:
        if (!mounted) return;
        await askRemindersSheet(context);
      case AfterAck.proSheet:
        if (!mounted) return;
        await askProSheet(context);
      case AfterAck.planMorningAfter:
        unawaited(getIt<ReminderPlanTrigger>().run());
      case AfterAck.proSheetLater:
        await store.writeProSheetOwed(owed: true);
      case AfterAck.nothing:
        break;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CriticalAlarmCubit, CriticalAlarmState>(
      listenWhen: (previous, current) =>
          !previous.isAcknowledged && current.isAcknowledged,
      listener: (context, state) {
        AppHaptics.success();
        setState(() {
          _direction = AmbientDirection.push;
        });
        unawaited(getIt<InAppNoticeRepository>().markAcknowledged());
        unawaited(_afterAck(state));
      },
      builder: (context, state) {
        final colors = context.appColors;
        final profile = state.isAcknowledged
            ? AmbientAppProfiles.criticalAlarmAcknowledged(colors)
            : AmbientAppProfiles.criticalAlarmRinging(colors);

        Widget content;
        if (!state.isLive && !state.isAcknowledged) {
          final isLoading = state.status == CriticalAlarmStatus.loading;
          final didFail = !isLoading && state.errorMessage != null;

          content = AppScreenScaffold(
            hasTabBar: false,
            topBar: AppTopBar(
              title: LocaleKeys.critical_alarm_screen_title.tr(),
              leading: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.critical_alarm_back_aria_label.tr(),
                onPressed: () => context.go('/'),
              ),
            ),
            // The load failing does not stop the phone ringing, so this screen
            // keeps a way out even when it has no incident to acknowledge.
            bottomBar: didFail
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        label: LocaleKeys.critical_alarm_retry_button.tr(),
                        isFullWidth: true,
                        onPressed: () => unawaited(
                          context.read<CriticalAlarmCubit>().load(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: LocaleKeys.critical_alarm_silence_button.tr(),
                        variant: AppButtonVariant.ghost,
                        isFullWidth: true,
                        onPressed: () {
                          AppHaptics.capture();
                          unawaited(
                            context
                                .read<CriticalAlarmCubit>()
                                .silenceThisPhone(),
                          );
                        },
                      ),
                    ],
                  )
                : null,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                sliver: SliverToBoxAdapter(
                  child: AppEmptyState(
                    title: isLoading
                        ? LocaleKeys.critical_alarm_loading_title.tr()
                        : didFail
                        ? LocaleKeys.critical_alarm_load_failed_title.tr()
                        : LocaleKeys.critical_alarm_no_alarm_title.tr(),
                    description: didFail
                        ? LocaleKeys.critical_alarm_load_failed_body.tr()
                        : isLoading
                        ? ''
                        : LocaleKeys.critical_alarm_no_alarm_body.tr(),
                    buttonLabel: null,
                    faceState: didFail ? FaceState.worried : FaceState.calm,
                    isLive: isLoading,
                  ),
                ),
              ),
            ],
          );
        } else {
          content = SeverityScope(
            mode: state.severityMode,
            child: Builder(
              builder: (context) {
                final colors = context.appColors;
                if (state.isAcknowledged) {
                  return AcknowledgedScreen(state: state, colors: colors);
                }
                // Back is not an acknowledge. It silences the phone and sets
                // the next ring for the same incident, the same as Stop on the
                // notification does, and only then lets the person out. Back
                // used to be swallowed whole, because leaving without
                // silencing left the phone screaming with no way back.
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) return;
                    final cubit = context.read<CriticalAlarmCubit>();
                    final router = GoRouter.of(context);
                    unawaited(cubit.silence().then((_) => router.go('/')));
                  },
                  child: _RingingScreen(state: state, colors: colors),
                );
              },
            ),
          );
        }

        return AmbientOverride(
          profile: profile,
          direction: _direction,
          child: content,
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
    final size = AppSize.of(context);
    final isWide = size.isExpanded || size.isShort;

    final bottomBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.errorMessage != null) ...[
          AppToast(
            faceState: FaceState.worried,
            message: state.errorMessage,
          ),
          const SizedBox(height: 8),
        ],
        AppButton(
          label: LocaleKeys.critical_alarm_acknowledge_button.tr(),
          isFullWidth: true,
          isLoading: state.isAcknowledging,
          onPressed: () {
            unawaited(context.read<CriticalAlarmCubit>().acknowledge());
          },
        ),
        const SizedBox(height: 8),
        // Silence is not an acknowledge. The noise stops, the incident stays
        // open, and the phone sets its own next ring for the same id.
        AppButton(
          label: LocaleKeys.critical_alarm_silence_ringing_button.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: () {
            AppHaptics.selection();
            unawaited(context.read<CriticalAlarmCubit>().silence());
          },
        ),
        const SizedBox(height: 8),
        // Hidden during onboarding: `demo-topic` is invented for the test and
        // is on no server, so opening it drops the user on a broken screen
        // halfway through setup.
        if (state.incident?.id != 'inc_demo')
          AppButton(
            label: LocaleKeys.critical_alarm_read_message_button.tr(),
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            // Reading is not acknowledging, so this leaves the alarm ringing
            // and takes the user to the messages on the topic.
            onPressed: state.incident == null
                ? null
                : () {
                    AppHaptics.selection();
                    unawaited(
                      context.push('/topics/${state.incident!.topic}'),
                    );
                  },
          ),
      ],
    );

    if (isWide) {
      return AppScreenScaffold(
        hasTabBar: false,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Row(
              children: [
                _face(300),
                const SizedBox(width: 40),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _word(TextAlign.left),
                        const SizedBox(height: Spacing.s2),
                        _topic(TextAlign.left),
                        _alarmCountPill(context),
                        const SizedBox(height: Spacing.s2),
                        _subtext(TextAlign.left),
                        const SizedBox(height: Spacing.s4),
                        _detailSheet(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottomBar: bottomBar,
      );
    }

    return AppScreenScaffold(
      hasTabBar: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s6, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _face(264),
                const SizedBox(height: Spacing.s4),
                _word(TextAlign.center),
                const SizedBox(height: Spacing.s2),
                _topic(TextAlign.center),
                _alarmCountPill(context),
                const SizedBox(height: Spacing.s2),
                _subtext(TextAlign.center),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s4, 16, 0),
            child: _detailSheet(),
          ),
        ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// How much wider the ringing face's stage is than its head.
  static const double _ringingStageScale = RingingFacePainter.stageUnits / 200;

  Widget _face(double faceSize) {
    final isDemo = state.incident?.id == 'inc_demo';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: faceSize,
        height: faceSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            PulseRingWidget(size: faceSize),
            Hero(
              tag: isDemo
                  ? 'onboarding-face'
                  : 'alarm-face-${state.incident?.id}',
              flightShuttleBuilder: faceFlightShuttleBuilder,
              // The ringing face's stage is wider than its head, to leave
              // room for sweat, stars and steam. This keeps the head the
              // size the old face was and lets the extras spill out.
              child: SizedBox.square(
                dimension: faceSize,
                child: OverflowBox(
                  maxWidth: faceSize * _ringingStageScale,
                  maxHeight: faceSize * _ringingStageScale,
                  child: ShufflingRingingFace(
                    size: faceSize * _ringingStageScale,
                    isLive: state.isLive,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _word(TextAlign align) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        state.word,
        textAlign: align,
        style: AppTypography.display(colors.onCanvas),
      ),
    );
  }

  Widget _topic(TextAlign align) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        state.topic,
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

  Widget _subtext(TextAlign align) {
    return Text(
      state.subtext,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: colors.onCanvas,
      ),
    );
  }

  /// The "2 alarms" pill under the topic name. Hidden until a second incident
  /// is open; tapping it opens the sheet that lists the others.
  Widget _alarmCountPill(BuildContext context) {
    final count = state.openIncidents.length;
    if (count <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s2),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () => unawaited(_showOtherAlarms(context)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.hairline.withValues(alpha: 0.5)),
            ),
            child: Text(
              LocaleKeys.critical_alarm_alarm_count_pill.plural(count),
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: colors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lists every open incident that is not the one on screen. Tapping a row
  /// swaps it to the top and answers nothing; the person still has to tap
  /// "I'm up" for the one they picked.
  Future<void> _showOtherAlarms(BuildContext context) async {
    final cubit = context.read<CriticalAlarmCubit>();
    final shownId = state.incident?.id;
    final others = state.openIncidents
        .where((i) => i.id != shownId)
        .toList(growable: false);
    await showAppSheet<void>(
      context: context,
      title: LocaleKeys.critical_alarm_alarm_others_sheet_title.tr(),
      content: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final incident in others)
            _OtherAlarmRow(
              incident: incident,
              onTap: () {
                cubit.select(incident.id);
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _detailSheet() {
    return AppSheet(
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
    );
  }
}

/// The acknowledged confirmation: how long it rang, when it started and was
/// acknowledged, where it came from, and the two pinned exits.
class AcknowledgedScreen extends StatelessWidget {
  const AcknowledgedScreen({
    required this.state,
    required this.colors,
    super.key,
  });

  final CriticalAlarmState state;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final incident = state.incident;
    final isDemo = incident?.id == 'inc_demo' || state.topic == 'demo-topic';
    // The same test alarm is reachable from Settings long after
    // onboarding. There is no first topic to create by then, so it ends
    // on one Finish rather than repeating the onboarding exits.
    final isRetest = isDemo && state.isOnboardingDone;
    final startedAt = incident?.openedAt;
    final ackedAt = incident?.ackedAt;
    final ringDuration = (startedAt != null && ackedAt != null)
        ? ackedAt.difference(startedAt)
        : null;
    final startedLabel = startedAt != null ? _formatClock(startedAt) : '';
    final ackedLabel = ackedAt != null ? _formatClock(ackedAt) : '';
    final ackedSub = isDemo
        ? LocaleKeys.onboarding_connect_celebration_subtitle.tr()
        : LocaleKeys.critical_alarm_acked_sub.tr(
            namedArgs: {
              'duration': ringDuration == null
                  ? ''
                  : _formatRingDuration(ringDuration),
            },
          );

    final size = AppSize.of(context);
    final isWide = size.isExpanded || size.isShort;
    final isClosed = state.status == CriticalAlarmStatus.closed;

    final bottomBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: isRetest
          ? [
              AppButton(
                label: LocaleKeys.onboarding_connect_celebration_finish.tr(),
                variant: AppButtonVariant.paper,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  context.go('/');
                },
              ),
            ]
          : isDemo
          ? [
              AppButton(
                label: LocaleKeys.onboarding_connect_create_first_topic_button
                    .tr(),
                variant: AppButtonVariant.paper,
                isFullWidth: true,
                onPressed: () async {
                  AppHaptics.capture();
                  await getIt<CompleteOnboardingUsecase>()(const NoParams());
                  if (context.mounted) {
                    context.go('/topics/new');
                  }
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: LocaleKeys.onboarding_connect_skip_to_dashboard.tr(),
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () async {
                  AppHaptics.capture();
                  await getIt<CompleteOnboardingUsecase>()(const NoParams());
                  if (context.mounted) {
                    context.go('/');
                  }
                },
              ),
            ]
          : isClosed
          ? [
              AppButton(
                label: LocaleKeys.critical_alarm_back_to_topics_button.tr(),
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  context.go('/');
                },
              ),
            ]
          : [
              _sub(TextAlign.center, _deskTimerHint(context)),
              const SizedBox(height: Spacing.s3),
              AppButton(
                label: LocaleKeys.critical_alarm_at_my_desk_button.tr(),
                variant: AppButtonVariant.paper,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  unawaited(context.read<CriticalAlarmCubit>().closeIncident());
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: LocaleKeys.critical_alarm_open_topic_button.tr(
                  namedArgs: {'topic': state.topic},
                ),
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  context.go('/topics/${state.topic}');
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: LocaleKeys.critical_alarm_back_to_topics_button.tr(),
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  context.go('/');
                },
              ),
            ],
    );

    if (isWide) {
      return AppScreenScaffold(
        hasTabBar: false,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Row(
              children: [
                Hero(
                  tag: isDemo
                      ? 'onboarding-face'
                      : 'alarm-face-${state.incident?.id}',
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(state: state.faceState, size: 260),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _title(TextAlign.left, isDemo),
                        const SizedBox(height: Spacing.s2),
                        _topic(TextAlign.left),
                        const SizedBox(height: Spacing.s2),
                        _sub(TextAlign.left, ackedSub),
                        const SizedBox(height: Spacing.s4),
                        _detailSheet(startedLabel, ackedLabel),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottomBar: bottomBar,
      );
    }

    return AppScreenScaffold(
      hasTabBar: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s6, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: isDemo
                      ? 'onboarding-face'
                      : 'alarm-face-${state.incident?.id}',
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(state: state.faceState, size: 224),
                ),
                const SizedBox(height: Spacing.s4),
                _title(TextAlign.center, isDemo),
                const SizedBox(height: Spacing.s2),
                _topic(TextAlign.center),
                const SizedBox(height: Spacing.s2),
                _sub(TextAlign.center, ackedSub),
                // Onboarding ends on "create your first topic", and the word
                // topic has not been explained anywhere before that button.
                if (isDemo && !isRetest) ...[
                  const SizedBox(height: Spacing.s3),
                  _sub(
                    TextAlign.center,
                    LocaleKeys.onboarding_connect_celebration_topics_hint.tr(),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s4, 16, 0),
            child: _detailSheet(startedLabel, ackedLabel),
          ),
        ),
      ],
      bottomBar: bottomBar,
    );
  }

  Widget _title(TextAlign align, bool isDemo) {
    return Text(
      isDemo
          ? LocaleKeys.onboarding_connect_celebration_title.tr()
          : LocaleKeys.critical_alarm_acked_title.tr(),
      textAlign: align,
      style: AppTypography.display(colors.onCanvas),
    );
  }

  Widget _topic(TextAlign align) {
    return Text(
      state.topic,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: colors.onCanvas,
      ),
    );
  }

  Widget _sub(TextAlign align, String text) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: colors.onCanvas,
      ),
    );
  }

  /// "Rings again in N min unless you tap At my desk." N comes from the
  /// topic's desk timer when the topic is in the cached list. A topic not
  /// loaded yet (or the demo, which is never in that list) falls back to the
  /// server default of 10 minutes rather than showing nothing.
  String _deskTimerHint(BuildContext context) {
    final topic = context.watch<TopicsCubit>().state.named(state.topic);
    final minutes = topic == null ? 10 : topic.deskTimerS ~/ 60;
    return LocaleKeys.critical_alarm_desk_timer_hint.tr(
      namedArgs: {'minutes': '$minutes'},
    );
  }

  Widget _detailSheet(String startedLabel, String ackedLabel) {
    return AppSheet(
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

/// One row in the "other alarms" sheet: the topic, the page title and how long
/// the incident has been open.
class _OtherAlarmRow extends StatelessWidget {
  const _OtherAlarmRow({required this.incident, required this.onTap});

  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = incident.messages.firstOrNull?.title ?? incident.topic;
    final openedAt = incident.openedAt;
    final age = openedAt == null
        ? ''
        : formatRingDuration(DateTime.now().difference(openedAt));

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.topic,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontFamilyFallback: AppTypography.fontMonoFallbacks,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: colors.ink3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                age,
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
    );
  }
}
