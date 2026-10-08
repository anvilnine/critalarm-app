import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/challenges/domain/challenge_gate.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/incidents/presentation/alarm_screen_reader.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/incidents/presentation/widgets/proof_list.dart';
import 'package:critalarm/features/incidents/presentation/widgets/ringing_screen.dart';
import 'package:critalarm/features/local_reminders/domain/after_ack_decider.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/presentation/widgets/local_reminder_ask_sheets.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Critical Alarm takeover screen matching docs/design-system/index.html.
class CriticalAlarmScreen extends StatelessWidget {
  const CriticalAlarmScreen({
    this.incidentId,
    this.previewsFirstToolAcked = false,
    super.key,
  });

  final String? incidentId;

  /// Opens on the acknowledged screen of a made-up first tool alarm. Only
  /// the router of a developer build sets it. Nothing is loaded or sent.
  final bool previewsFirstToolAcked;

  /// The query parameter and value that ask for that look.
  static const previewParam = 'show';
  static const previewFirstToolAcked = 'first_tool_acked';

  /// Where Developer options opens it.
  static const previewFirstToolAckedLocation =
      '/incidents/inc_preview?$previewParam=$previewFirstToolAcked';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<CriticalAlarmCubit>();
        if (previewsFirstToolAcked) {
          cubit.previewFirstToolAlarm();
        } else {
          unawaited(cubit.load(incidentId: incidentId));
        }
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

  /// The "I'm up" button, so a screen reader can be put on it.
  final GlobalKey _ackButtonKey = GlobalKey();

  /// The ringing announcement is made once for the life of this screen, even
  /// when the ringing layout comes back after an acknowledge the server
  /// refused.
  bool _didAnnounceRinging = false;

  /// The challenge on screen, and the incident it belongs to. It shows
  /// only while that incident is the acknowledged one on screen, so
  /// another alarm taking the screen over leaves it.
  ChallengeOwed? _challenge;
  String? _challengeIncidentId;

  /// "At my desk" on the acknowledged screen. With no challenge owed it
  /// closes the incident, as it always has. With one owed it opens the
  /// challenge, and passing or leaving that makes the same close.
  ///
  /// Nothing here runs before "I'm up": the ring is already stopped.
  void _atMyDesk(CriticalAlarmState state) {
    final cubit = context.read<CriticalAlarmCubit>();
    final incident = state.incident;
    ChallengeDue due = const ChallengeNotOwed(NoChallengeReason.cannotRun);
    if (incident != null && !state.isPreview) {
      try {
        due = getIt<ChallengeGate>().dueFor(
          incidentId: incident.id,
          incident: _challengeIncident(state),
          isScreenReaderOn: MediaQuery.accessibleNavigationOf(context),
        );
      } on Object catch (_) {
        // A challenge that cannot be worked out is no challenge.
      }
    }
    final owed = due;
    if (owed is ChallengeOwed &&
        incident != null &&
        challengeOf(owed.kind) != null) {
      setState(() {
        _challenge = owed;
        _challengeIncidentId = incident.id;
      });
      return;
    }
    unawaited(cubit.closeIncident());
  }

  /// The words the acknowledged screen shows, which is all a challenge may
  /// compare against.
  ChallengeIncident _challengeIncident(CriticalAlarmState state) =>
      ChallengeIncident(
        topic: state.topic,
        alertTitle: state.title.isEmpty ? null : state.title,
      );

  /// The challenge to draw for [state], or null. Only for the incident it
  /// was opened for, and only while that one waits for "At my desk".
  ChallengeOwed? _challengeFor(CriticalAlarmState state) {
    final challenge = _challenge;
    if (challenge == null) return null;
    if (state.incident?.id != _challengeIncidentId) return null;
    if (state.status != CriticalAlarmStatus.acknowledged) return null;
    if (state.ackedExits != AckedExits.incident) return null;
    return challenge;
  }

  void _leaveChallenge() {
    if (_challenge == null) return;
    setState(() {
      _challenge = null;
      _challengeIncidentId = null;
    });
  }

  /// The challenge was passed, or the way out was used. Either way the
  /// incident is closed through the call "At my desk" always made.
  void _finishChallenge() {
    final id = _challengeIncidentId;
    final cubit = context.read<CriticalAlarmCubit>();
    if (id != null) {
      try {
        getIt<ChallengeGate>().markCleared(id);
      } on Object catch (_) {
        // The close below does not depend on it.
      }
    }
    _leaveChallenge();
    // Only the incident the challenge was for. If another took the screen
    // in the same moment, that one is left alone.
    if (id != null && cubit.state.incident?.id == id) {
      AppHaptics.capture();
      unawaited(cubit.closeIncident());
    }
  }

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
    final store = getIt<LocalReminderStore>();
    final notices = getIt<InAppNoticeRepository>();
    final incident = state.incident;
    // A delivered review or feedback reminder counts as an ask before the
    // Pro rules read the ask times.
    await getIt<LocalReminderSettler>().settleAsks(now: DateTime.now());
    final proShouldAsk = await getIt<ProAskRules>().shouldAsk();
    final now = DateTime.now();
    final lastSheet = notices.getAfterAckSheetShownAt();
    final next = AfterAckDecider.decide(
      isSetupDone: await getIt<SetupGate>().isDone(),
      ackedAt: now,
      isTestAck: incident == null || IncidentKinds.isTest(incident),
      isLocalRemindersSheetShown: store.readSheetShown(),
      isWeb: getIt<PlatformCapabilities>().isWeb,
      offersOn: store.readSwitches().offers,
      proShouldAsk: proShouldAsk,
      hasOtherOpenIncident: cubit.state.openIncidents.isNotEmpty,
      alreadyShownToday: lastSheet != null && _sameDay(lastSheet, now),
      isOfferAhead: await getIt<OnboardingOfferGate>().isAhead(),
    );
    // Stamped before the sheet opens, so the second ack of the same day gets
    // nothing whichever of the two was shown.
    if (next == AfterAck.localRemindersSheet || next == AfterAck.proSheet) {
      await notices.markAfterAckSheetShown();
    }
    // Only the two sheets need this screen. Planning the morning after and
    // owing the Pro sheet happen even if the user already left it.
    switch (next) {
      case AfterAck.localRemindersSheet:
        if (!mounted) return;
        await askLocalRemindersSheet(context);
      case AfterAck.proSheet:
        if (!mounted) return;
        await askProSheet(context, trigger: HostedAskTrigger.afterAck);
      case AfterAck.planMorningAfter:
        unawaited(getIt<LocalReminderPlanTrigger>().run());
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
    // Another incident is on screen now, so a challenge opened for the one
    // before is left. It is not carried over, and nothing is owed here
    // until "At my desk" is tapped for this one.
    return BlocListener<CriticalAlarmCubit, CriticalAlarmState>(
      listenWhen: (previous, current) =>
          previous.incident?.id != current.incident?.id,
      listener: (context, state) => _leaveChallenge(),
      child: _buildAlarm(context),
    );
  }

  Widget _buildAlarm(BuildContext context) {
    return BlocConsumer<CriticalAlarmCubit, CriticalAlarmState>(
      listenWhen: (previous, current) =>
          !previous.isAcknowledged && current.isAcknowledged,
      listener: (context, state) {
        AppHaptics.success();
        setState(() {
          _direction = AmbientDirection.push;
        });
        // An alarm setup itself caused (its test, or the first hook-up
        // message) is not real use: it stamps nothing and opens no sheet.
        final isRealUse = countsAsRealUse(
          incidentId: state.incident?.id,
          setupIncidentIds: getIt<SetupTestRing>().setupIncidentIds,
        );
        if (!isRealUse) return;
        unawaited(getIt<InAppNoticeRepository>().markAcknowledged());
        final incident = state.incident;
        if (countsAsFirstRealAck(
          incidentId: incident?.id,
          isTest: incident == null || IncidentKinds.isTest(incident),
          setupIncidentIds: getIt<SetupTestRing>().setupIncidentIds,
        )) {
          unawaited(getIt<InAppNoticeRepository>().markFirstRealAcknowledged());
        }
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
                    faceState: didFail ? FaceState.worried : FaceState.calm,
                    isLive: isLoading,
                  ),
                ),
              ),
            ],
          );
        } else {
          content = SeverityScope(
            // The acknowledged screen stays on the acknowledged canvas after
            // At my desk closes the incident, so its text keeps the colours
            // that read on it.
            mode: state.isAcknowledged ? SeverityMode.ack : state.severityMode,
            child: Builder(
              builder: (context) {
                final colors = context.appColors;
                if (state.isAcknowledged) {
                  final owed = _challengeFor(state);
                  final challenge = challengeOf(owed?.kind);
                  if (owed != null && challenge != null) {
                    return ChallengeStep(
                      key: ValueKey('challenge-${state.incident?.id}'),
                      challenge: challenge,
                      incident: _challengeIncident(state),
                      wayOut: owed.wayOut,
                      onPassed: _finishChallenge,
                      onSkip: _finishChallenge,
                      onLeave: _leaveChallenge,
                    );
                  }
                  return AcknowledgedScreen(
                    state: state,
                    colors: colors,
                    onAtMyDesk: () => _atMyDesk(state),
                  );
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
                  child: _RingingScreenReader(
                    state: state,
                    ackButtonKey: _ackButtonKey,
                    announces: !_didAnnounceRinging,
                    onAnnounced: () => _didAnnounceRinging = true,
                    child: RingingScreen(
                      state: state,
                      colors: colors,
                      ackButtonKey: _ackButtonKey,
                      onAcknowledge: () {
                        unawaited(
                          context.read<CriticalAlarmCubit>().acknowledge(),
                        );
                      },
                      onSilence: () {
                        AppHaptics.selection();
                        unawaited(context.read<CriticalAlarmCubit>().silence());
                      },
                      // Reading is not acknowledging, so this leaves the
                      // alarm ringing and takes the user to the messages
                      // on the topic.
                      onReadMessage: state.incident == null
                          ? null
                          : () {
                              AppHaptics.selection();
                              unawaited(
                                context.push(
                                  '/topics/${state.incident!.topic}',
                                ),
                              );
                            },
                      onSelectAlarm: (id) =>
                          context.read<CriticalAlarmCubit>().select(id),
                    ),
                  ),
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

/// What the ringing screen does for a screen reader, and nothing a sighted
/// user can see: it puts the reader on "I'm up", says once which topic is
/// ringing and for how long, and takes the VoiceOver magic tap.
class _RingingScreenReader extends StatefulWidget {
  const _RingingScreenReader({
    required this.state,
    required this.ackButtonKey,
    required this.announces,
    required this.onAnnounced,
    required this.child,
  });

  final CriticalAlarmState state;
  final GlobalKey ackButtonKey;

  /// False once this screen has made its announcement.
  final bool announces;
  final VoidCallback onAnnounced;
  final Widget child;

  @override
  State<_RingingScreenReader> createState() => _RingingScreenReaderState();
}

class _RingingScreenReaderState extends State<_RingingScreenReader>
    with WidgetsBindingObserver {
  /// Long enough for the reader to say "I'm up, button" first. An
  /// announcement made in the same moment as the focus move is cut off by it.
  static const _announceDelay = Duration(seconds: 1);

  /// The ringing screens in front right now. The magic tap stays armed on
  /// the phone while there is one, whichever order two screens report in.
  static final Set<Object> _inFrontScreens = <Object>{};

  late final AlarmHost _host = getIt<AlarmHost>();
  StreamSubscription<void>? _magicTaps;
  Timer? _announceTimer;
  bool _isRouteCurrent = false;
  AppLifecycleState? _lifecycle;
  bool _isInFront = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<CriticalAlarmCubit>();
    _magicTaps = _host.magicTaps.listen((_) {
      // The same path as the button. The cubit turns it down unless the
      // alarm is ringing and this screen is the one in front.
      unawaited(
        cubit.acknowledgeFromMagicTap(isRingingScreenInFront: _isInFront),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while a sheet or another screen covers this one.
    _isRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _updateInFront();
  }

  /// Control Center, the notification shade, a call and the app switcher
  /// leave the route current, so the route alone does not say the screen is
  /// in front. Anything but resumed disarms the magic tap; resumed arms it
  /// again when the route is still current.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _updateInFront();
  }

  void _updateInFront() => _setInFront(
    isRingingScreenInFront(
      isRouteCurrent: _isRouteCurrent,
      lifecycle: _lifecycle,
    ),
  );

  void _setInFront(bool isInFront) {
    if (isInFront == _isInFront) return;
    _isInFront = isInFront;
    if (isInFront) {
      _inFrontScreens.add(this);
    } else {
      _inFrontScreens.remove(this);
    }
    unawaited(_host.setMagicTapArmed(isArmed: _inFrontScreens.isNotEmpty));
  }

  /// Runs once the first ringing frame is up. Does nothing without a screen
  /// reader.
  void _greet() {
    if (!mounted || !MediaQuery.accessibleNavigationOf(context)) return;
    widget.ackButtonKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    if (!widget.announces) return;
    widget.onAnnounced();
    final view = View.of(context);
    final direction = Directionality.of(context);
    _announceTimer = Timer(_announceDelay, () {
      // A sheet that opened, or an app that left the front, inside the delay:
      // the announcement is dropped, never said over something else or later.
      if (!mounted || !_isInFront) return;
      final state = widget.state;
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          ringingAnnouncement(
            topic: state.topic,
            ringTime: state.ringTimeSpoken,
            openAlarms: state.openIncidents.length,
          ),
          direction,
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _announceTimer?.cancel();
    unawaited(_magicTaps?.cancel());
    _setInFront(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The acknowledged confirmation: how long it rang, when it started and was
/// acknowledged, where it came from, and the two pinned exits.
class AcknowledgedScreen extends StatelessWidget {
  const AcknowledgedScreen({
    required this.state,
    required this.colors,
    this.onAtMyDesk,
    super.key,
  });

  final CriticalAlarmState state;
  final AppColors colors;

  /// Takes over the tap on "At my desk", for an owner that may ask for a
  /// wake-up challenge first. Left out, the button closes the incident.
  final VoidCallback? onAtMyDesk;

  @override
  Widget build(BuildContext context) {
    final incident = state.incident;
    // Which test this was, and so which exits it ends on. A setup run on a
    // flow with the real ring step continues; the first shipped order and a
    // test run again from Settings keep the exits they always had.
    final setupTest = state.setupTest;
    final exits = state.ackedExits;
    final isDemo = exits != AckedExits.incident;
    final startedAt = incident?.openedAt;
    final ackedAt = incident?.ackedAt;
    final ringDuration = (startedAt != null && ackedAt != null)
        ? ackedAt.difference(startedAt)
        : null;
    final startedLabel = startedAt != null ? _formatClock(startedAt) : '';
    final ackedLabel = ackedAt != null ? _formatClock(ackedAt) : '';
    final ackedSub = LocaleKeys.critical_alarm_acked_sub.tr(
      namedArgs: {
        'duration': ringDuration == null
            ? ''
            : _formatRingDuration(ringDuration),
      },
    );
    // The demo welcomes: a ripple of happy faces, the title and one line,
    // with confetti on top.
    final faceState = state.faceState;
    // The face keeps the outline and features it has everywhere else. The
    // acknowledged palette turns both white for the text around it.
    final facePalette = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    final size = AppSize.of(context);
    final isWide = size.isExpanded || size.isShort;
    final isClosed = state.status == CriticalAlarmStatus.closed;
    // The hint is pinned over At my desk. At a large text size it runs to
    // several lines and the pinned block would take half a small screen,
    // so it goes into the list, under the details card.
    final pinsHint = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final hintInList = !isClosed && !pinsHint;

    final bottomBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: isDemo
          ? [
              ...switch (exits) {
                // Setup goes on. The flow says what comes next, and ends
                // setup itself when nothing does.
                AckedExits.continueSetup => [
                  _ContinueSetupButton(
                    setupTest: setupTest,
                    incidentId: incident?.id ?? '',
                  ),
                ],
                // The user's own tool rang the phone: setup is proved. One
                // button, which ends that one incident and goes Home.
                AckedExits.firstToolAlarm => [
                  _FinishFirstToolButton(incidentId: incident?.id ?? ''),
                ],
                // Onboarding is done, so the only thing left is the way out.
                AckedExits.retest => [
                  AppButton(
                    label: LocaleKeys.onboarding_connect_celebration_finish
                        .tr(),
                    variant: AppButtonVariant.cream,
                    size: AppButtonSize.lg,
                    isFullWidth: true,
                    onPressed: () {
                      AppHaptics.capture();
                      context.go('/');
                    },
                  ),
                ],
                AckedExits.legacyFinish => [
                  AppButton(
                    label: LocaleKeys.onboarding_connect_celebration_finish
                        .tr(),
                    variant: AppButtonVariant.cream,
                    size: AppButtonSize.lg,
                    isFullWidth: true,
                    onPressed: () async {
                      AppHaptics.capture();
                      await getIt<CompleteOnboardingUsecase>()(
                        const NoParams(),
                      );
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                  ),
                ],
                AckedExits.legacyCreateTopicOrFinish || AckedExits.incident => [
                  // The first topic is the next step. Cream, because cobalt
                  // on the navy acknowledged canvas would disappear.
                  AppButton(
                    label: LocaleKeys
                        .onboarding_connect_create_first_topic_button
                        .tr(),
                    variant: AppButtonVariant.cream,
                    size: AppButtonSize.lg,
                    isFullWidth: true,
                    onPressed: () async {
                      AppHaptics.capture();
                      await getIt<CompleteOnboardingUsecase>()(
                        const NoParams(),
                      );
                      if (context.mounted) {
                        context.go('/topics/new');
                      }
                    },
                  ),
                  const SizedBox(height: Spacing.s3),
                  // Ghost reads on the navy canvas and ranks below Create.
                  AppButton(
                    label: LocaleKeys.onboarding_connect_celebration_finish
                        .tr(),
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.lg,
                    isFullWidth: true,
                    onPressed: () async {
                      AppHaptics.capture();
                      await getIt<CompleteOnboardingUsecase>()(
                        const NoParams(),
                      );
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                  ),
                ],
              },
              // 12px from the scaffold makes 24 above the home indicator.
              const SizedBox(height: 12),
            ]
          : [
              // At most two buttons. Back to topics is the way out and is
              // always the paper one at the bottom. Above it, while the
              // desk timer runs, sits At my desk. The way to the topic is
              // the pill under the title, in both states and only there.
              if (!isClosed) ...[
                if (pinsHint) ...[
                  _sub(TextAlign.center, _deskTimerHint(context)),
                  const SizedBox(height: Spacing.s3),
                ],
                AppButton(
                  label: LocaleKeys.critical_alarm_at_my_desk_button.tr(),
                  variant: AppButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () {
                    AppHaptics.capture();
                    final onAtMyDesk = this.onAtMyDesk;
                    if (onAtMyDesk != null) {
                      onAtMyDesk();
                      return;
                    }
                    unawaited(
                      context.read<CriticalAlarmCubit>().closeIncident(),
                    );
                  },
                ),
                const SizedBox(height: Spacing.s2),
              ],
              AppButton(
                label: LocaleKeys.critical_alarm_back_to_topics_button.tr(),
                variant: AppButtonVariant.paper,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  context.go('/');
                },
              ),
            ],
    );

    // Setup going on, and the alarm the user's own tool set off, both say
    // what the ring proved.
    final provesSetup =
        exits == AckedExits.continueSetup || exits == AckedExits.firstToolAlarm;

    if (isDemo) {
      return _demoBody(
        context,
        isWide,
        bottomBar,
        // Setup going on says what the ring proved, as a short list of
        // ticks. The other exits keep the welcome they always had.
        title: provesSetup
            ? LocaleKeys.onboarding_real_ring_works_title.tr()
            : LocaleKeys.onboarding_connect_welcome_title.tr(),
        detail: provesSetup
            ? ProofList(
                lines: _proofLines(
                  exits == AckedExits.firstToolAlarm
                      ? firstToolAlarmProof
                      : setupProofFor(setupTest),
                ),
              )
            : Text(
                LocaleKeys.onboarding_connect_welcome_body.tr(),
                textAlign: isWide ? TextAlign.left : TextAlign.center,
                style: _bodyStyle(18, FontWeight.w500, colors.onCanvas),
              ),
        // A partial proof gets a calmer wall than the full one, so the two
        // differ in feel as well as in words.
        restFaces:
            exits == AckedExits.continueSetup &&
                setupTest != SetupTestKind.serverSent
            ? quietRestFaces
            : celebrationRestFaces,
      );
    }

    if (isWide) {
      return AppScreenScaffold(
        hasTabBar: false,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Row(
              children: [
                Hero(
                  tag: 'alarm-face-${state.incident?.id}',
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(
                    state: faceState,
                    size: 260,
                    overrideStrokeColor: facePalette.faceStroke,
                    overrideInkColor: facePalette.faceInk,
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _title(TextAlign.left),
                        const SizedBox(height: Spacing.s2),
                        _topic(context),
                        const SizedBox(height: Spacing.s2),
                        _sub(TextAlign.left, ackedSub),
                        const SizedBox(height: Spacing.s4),
                        _detailSheet(startedLabel, ackedLabel),
                        if (hintInList) ...[
                          const SizedBox(height: Spacing.s4),
                          _sub(TextAlign.left, _deskTimerHint(context)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottomBar: bottomBar,
        barBacking: colors.canvas,
      );
    }

    // The face takes what the rest leaves. Everything else on the screen
    // has a size of its own (title, pill, line, the three-row card, the
    // hint and the two buttons, about [_restHeight] at the default text
    // size), so on a short phone the face shrinks until the whole card
    // sits above the pinned buttons with nothing hidden at rest. At a large
    // text size the list scrolls, and the room the scaffold leaves under
    // it is the height of the backing, so the card always scrolls clear.
    final media = MediaQuery.of(context);
    final faceSize = (media.size.height - media.padding.vertical - _restHeight)
        .clamp(
          _minFace,
          224.0,
        );

    return AppScreenScaffold(
      hasTabBar: false,
      // The list scrolls under the pinned hint and buttons at a large text
      // size or on a short phone. A solid backing in the canvas colour
      // keeps the card from showing through them.
      barBacking: colors.canvas,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, Spacing.s5, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'alarm-face-${state.incident?.id}',
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(
                    state: faceState,
                    size: faceSize,
                    overrideStrokeColor: facePalette.faceStroke,
                    overrideInkColor: facePalette.faceInk,
                  ),
                ),
                const SizedBox(height: Spacing.s4),
                _title(TextAlign.center),
                const SizedBox(height: Spacing.s2),
                _topic(context),
                const SizedBox(height: Spacing.s2),
                _sub(TextAlign.center, ackedSub),
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
        if (hintInList)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, Spacing.s4, 20, 0),
              child: _sub(TextAlign.center, _deskTimerHint(context)),
            ),
          ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// The test alarm's acknowledged screen: a ripple of happy faces as the
  /// picture, then the welcome title, a line and the way on,
  /// with confetti over all of it. The ripple takes whatever height the text
  /// and button leave, so nothing scrolls off a small phone.
  Widget _demoBody(
    BuildContext context,
    bool isWide,
    Widget bottomBar, {
    required String title,
    required Widget detail,
    required List<FaceState> restFaces,
  }) {
    final ripple = ExcludeSemantics(
      child: IgnorePointer(
        child: FaceRipple(
          faces: happyRippleFaces,
          restFace: FaceState.content,
          restFaces: restFaces,
          randomFaces: true,
        ),
      ),
    );
    Widget copy(TextAlign align, CrossAxisAlignment cross) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          Text(
            title,
            textAlign: align,
            style: AppTypography.display(colors.onCanvas),
          ),
          const SizedBox(height: Spacing.s4),
          detail,
        ],
      ),
    );
    final bottomGap = MediaQuery.paddingOf(context).bottom + 24;
    final scaffold = AppScreenScaffold(
      hasTabBar: false,
      // The column below is sized to the screen, so the list has no room to
      // scroll and no reason to bounce.
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: isWide
              ? Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, bottomGap),
                  child: Row(
                    children: [
                      Expanded(child: ripple),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  copy(
                                    TextAlign.left,
                                    CrossAxisAlignment.start,
                                  ),
                                  const SizedBox(height: Spacing.s5),
                                  bottomBar,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(24, Spacing.s4, 24, bottomGap),
                  child: Column(
                    children: [
                      Expanded(child: ripple),
                      const SizedBox(height: Spacing.s5),
                      copy(TextAlign.center, CrossAxisAlignment.center),
                      const SizedBox(height: Spacing.s6),
                      bottomBar,
                    ],
                  ),
                ),
        ),
      ],
    );
    return Stack(
      children: [
        scaffold,
        Positioned.fill(child: _AckConfetti(colors: colors)),
      ],
    );
  }

  /// The words for each line of the proof list. What a test did not prove
  /// says so in its own words, never with a tick left empty.
  static List<ProofListLine> _proofLines(List<ProofLine> proof) {
    // With nothing else proved, the phone line is the whole claim.
    final isPhoneOnly = proof.where((line) => line.isProved).length == 1;
    return [
      for (final line in proof)
        (
          isProved: line.isProved,
          text: switch (line.point) {
            ProofPoint.toolSent =>
              LocaleKeys.onboarding_real_ring_proof_tool_sent.tr(),
            ProofPoint.delivered =>
              LocaleKeys.onboarding_real_ring_proof_delivered.tr(),
            ProofPoint.serverSent =>
              line.isProved
                  ? LocaleKeys.onboarding_real_ring_proof_server_sent.tr()
                  : LocaleKeys.onboarding_real_ring_proof_server_untested.tr(),
            ProofPoint.pushArrived =>
              line.isProved
                  ? LocaleKeys.onboarding_real_ring_proof_push_arrived.tr()
                  : LocaleKeys.onboarding_real_ring_proof_push_untested.tr(),
            ProofPoint.phoneRang =>
              isPhoneOnly
                  ? LocaleKeys.onboarding_real_ring_proof_phone_rings.tr()
                  : LocaleKeys.onboarding_real_ring_proof_phone_rang.tr(),
          },
        ),
    ];
  }

  static TextStyle _bodyStyle(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: weight,
        fontSize: size,
        height: 1.4,
        color: color,
      );

  /// What the acknowledged screen needs besides its face, at the default
  /// text size, and the smallest face that still reads as the face.
  static const double _restHeight = 556;
  static const double _minFace = 88;

  /// One line on any phone at the default text size: the type scales down
  /// until the word fits, and it never breaks inside a word.
  Widget _title(TextAlign align) {
    return AppFittedTitle(
      LocaleKeys.critical_alarm_acked_title.tr(),
      textAlign: align,
      style: AppTypography.display(colors.onCanvas),
    );
  }

  void _openTopic(BuildContext context) {
    AppHaptics.capture();
    context.go('/topics/${state.topic}');
  }

  /// The topic, as the way to its page: the name in a quiet pill with an
  /// arrow. It is there in both states, so the message is one tap away
  /// while At my desk holds the button slot.
  Widget _topic(BuildContext context) {
    return Semantics(
      button: true,
      label: LocaleKeys.critical_alarm_open_topic_button.tr(
        namedArgs: {'topic': state.topic},
      ),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openTopic(context),
        child: ConstrainedBox(
          // A full-size target around a small pill.
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.canvasGhostStrong,
                borderRadius: Radii.fullAll,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        state.topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.monoBold(
                          colors.onCanvas,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppGlyph(
                      GlyphType.arrow,
                      color: colors.onCanvas,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

/// Continue, on the acknowledged screen of a setup test.
///
/// It finishes the real ring step and lets the flow decide what comes next.
/// It never completes setup itself: the flow engine does, when no step is
/// left.
class _ContinueSetupButton extends StatefulWidget {
  const _ContinueSetupButton({
    required this.setupTest,
    required this.incidentId,
  });

  final SetupTestKind setupTest;

  /// The test this button was drawn for.
  final String incidentId;

  @override
  State<_ContinueSetupButton> createState() => _ContinueSetupButtonState();
}

class _ContinueSetupButtonState extends State<_ContinueSetupButton> {
  bool _isBusy = false;

  Future<void> _continue() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    AppHaptics.capture();
    final cubit = context.read<CriticalAlarmCubit>();
    // The server-sent test is a real incident. Acknowledged and left open,
    // its desk timer would ring the phone again later as a real alarm, so
    // every test of this run is closed. The cubit does that only for the
    // test this button was drawn for, and says whether that test is still
    // what the screen shows afterwards.
    final mayContinue = widget.setupTest == SetupTestKind.serverSent
        ? await cubit.closeSetupTests(widget.incidentId)
        : cubit.state.incident?.id == widget.incidentId;
    if (!mounted) return;
    // A real alarm took the screen over. Setup waits; the alarm does not.
    if (mayContinue) {
      await finishOnboardingStep(context, OnboardingStepId.realRing);
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: LocaleKeys.onboarding_welcome_continue.tr(),
      variant: AppButtonVariant.cream,
      size: AppButtonSize.lg,
      isFullWidth: true,
      isLoading: _isBusy,
      onPressed: _continue,
    );
  }
}

/// The one button on the acknowledged screen of the alarm the user's own
/// tool set off from the last setup step.
///
/// Setup is already complete by then: the hook-up step finished it before
/// it handed over to the alarm. So this ends that one incident, which would
/// otherwise ring again from its desk timer, and goes Home.
class _FinishFirstToolButton extends StatefulWidget {
  const _FinishFirstToolButton({required this.incidentId});

  /// The alarm this button was drawn for.
  final String incidentId;

  @override
  State<_FinishFirstToolButton> createState() => _FinishFirstToolButtonState();
}

class _FinishFirstToolButtonState extends State<_FinishFirstToolButton> {
  bool _isBusy = false;

  Future<void> _finish() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    AppHaptics.capture();
    final router = GoRouter.of(context);
    final cubit = context.read<CriticalAlarmCubit>();
    try {
      final mayLeave = await cubit.finishFirstToolAlarm(widget.incidentId);
      // Another alarm took the screen over, or this stopped being the
      // first tool alarm. The screen stays and shows what it now is.
      if (mayLeave) router.go('/');
    } finally {
      // Whatever happened, the one button is never left spinning.
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: LocaleKeys.onboarding_connect_celebration_finish.tr(),
      variant: AppButtonVariant.cream,
      size: AppButtonSize.lg,
      isFullWidth: true,
      isLoading: _isBusy,
      onPressed: _finish,
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

/// Two confetti bursts that fire once when the demo's acknowledged screen
/// appears. Under reduce motion nothing is thrown. Brand colours only, no
/// crit red.
class _AckConfetti extends StatefulWidget {
  const _AckConfetti({required this.colors});

  final AppColors colors;

  @override
  State<_AckConfetti> createState() => _AckConfettiState();
}

class _AckConfettiState extends State<_AckConfetti> {
  final _left = ConfettiController(duration: const Duration(seconds: 2));
  final _right = ConfettiController(duration: const Duration(seconds: 2));
  bool _started = false;

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) return;
    AppHaptics.success();
    _left.play();
    _right.play();
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final palette = [c.yellow, c.cobalt, c.surface, c.highlight];
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-1, 0.35),
            child: ConfettiWidget(
              confettiController: _left,
              blastDirection: -math.pi / 3,
              emissionFrequency: 0.08,
              numberOfParticles: 14,
              maxBlastForce: 45,
              minBlastForce: 20,
              gravity: 0.25,
              colors: palette,
            ),
          ),
          Align(
            alignment: const Alignment(1, 0.35),
            child: ConfettiWidget(
              confettiController: _right,
              blastDirection: -2 * math.pi / 3,
              emissionFrequency: 0.08,
              numberOfParticles: 14,
              maxBlastForce: 45,
              minBlastForce: 20,
              gravity: 0.25,
              colors: palette,
            ),
          ),
        ],
      ),
    );
  }
}
