import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_screen_host.dart';
import 'package:critalarm/core/format/clock_format.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/challenges/domain/challenge_gate.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/incidents/domain/ack_confetti_rule.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_latch.dart';
import 'package:critalarm/features/incidents/domain/loudness_ask.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/incidents/domain/ringing_layout_rules.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/incidents/presentation/alarm_screen_reader.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/incidents/presentation/lock_screen_hold.dart';
import 'package:critalarm/features/incidents/presentation/widgets/loud_enough_ask.dart';
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
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part 'critical_alarm_acknowledged.dart';
part 'critical_alarm_acknowledged_confetti.dart';
part 'critical_alarm_acknowledged_demo.dart';
part 'critical_alarm_acknowledged_exits.dart';
part 'critical_alarm_acknowledged_layouts.dart';
part 'critical_alarm_screen_live.dart';
part 'critical_alarm_screen_no_ring.dart';
part 'critical_alarm_screen_reader.dart';

/// Critical Alarm takeover screen matching docs/design-system/index.html.
class CriticalAlarmScreen extends StatelessWidget {
  const CriticalAlarmScreen({
    this.incidentId,
    this.previewsFirstToolAcked = false,
    this.cameFromDone = false,
    super.key,
  });

  final String? incidentId;

  /// A native Done button opened this screen: the link carried
  /// `PushDeepLink.fromDone`. See `CriticalAlarmCubit.load`.
  final bool cameFromDone;

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
          unawaited(
            cubit.load(incidentId: incidentId, cameFromDone: cameFromDone),
          );
        }
        return cubit;
      },
      child: _CriticalAlarmView(routeIncidentId: incidentId),
    );
  }
}

class _CriticalAlarmView extends StatefulWidget {
  const _CriticalAlarmView({required this.routeIncidentId});

  /// The incident the route named. The screen may move on to another one.
  final String? routeIncidentId;

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

  /// Incidents whose challenge was passed or left on this screen since
  /// they were last acknowledged. If the close that followed failed, the
  /// next "At my desk" closes with no second challenge. An incident that
  /// rings again is taken out, so its next acknowledge owes one again.
  final Set<String> _clearedIncidentIds = <String>{};

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
          incident: _challengeIncident(state),
          isScreenReaderOn: MediaQuery.accessibleNavigationOf(context),
          isCleared: _clearedIncidentIds.contains(incident.id),
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
  ///
  /// When the first message has no title (a topic whose content mode hides
  /// it), the cubit puts a fallback line in `state.title`. That line is not
  /// a title, so no alert title is passed. The test is the message's own
  /// `title` being null or empty, never the text of the line.
  ChallengeIncident _challengeIncident(CriticalAlarmState state) {
    final sent = state.incident?.messages.firstOrNull?.title;
    final hasRealTitle = sent != null && sent.isNotEmpty;
    return ChallengeIncident(
      topic: state.topic,
      alertTitle: hasRealTitle && state.title.isNotEmpty ? state.title : null,
    );
  }

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
    if (id != null) _clearedIncidentIds.add(id);
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

  /// Keeps the look of the incident on screen still while it is on screen.
  final AlarmStyleLatch _lookLatch = AlarmStyleLatch();

  /// Lets the Android window leave the lock screen once this screen stops
  /// ringing, opens another screen on top, or goes away.
  ///
  /// The same moments start and stop the iPhone's full brightness and
  /// vibration (`RingScreenHost`), which only the open, ringing screen gets.
  late final LockScreenHold _lockHold = LockScreenHold(
    release: (id) {
      _withRingScreen((host) => host.stop());
      return _withAlarmHost((host) => host.releaseLockScreen(id));
    },
    hold: (id) {
      unawaited(_withAlarmHost((host) => host.holdLockScreen(id)));
      _withRingScreen((host) => host.start(topic: _ringingTopic));
    },
    onSettled: () {
      if (mounted) setState(() {});
    },
    holdsWindow: defaultTargetPlatform == TargetPlatform.android,
  );

  /// The topic of the ringing incident, for the sound its pattern follows.
  String? _ringingTopic;

  /// The last state that drew the ringing layout. Drawn in place of the
  /// acknowledged and failure layouts until the window has left the lock
  /// screen ([LockScreenHold.mayShowOverLock]).
  CriticalAlarmState? _lastRinging;

  static Future<void> _withAlarmHost(
    Future<void> Function(AlarmHost host) call,
  ) async {
    if (!getIt.isRegistered<AlarmHost>()) return;
    await call(getIt<AlarmHost>());
  }

  static void _withRingScreen(Future<void> Function(RingScreenHost host) call) {
    if (!getIt.isRegistered<RingScreenHost>()) return;
    unawaited(call(getIt<RingScreenHost>()));
  }

  /// What the screen draws for [current]. A screen that stops ringing keeps
  /// its last ringing frame while the window may still be over the lock
  /// screen, so the acknowledged and failure layouts draw only once it has
  /// left. On an unlocked phone that is the next frame. On a locked one it
  /// is after the unlock prompt, which covers the screen meanwhile.
  CriticalAlarmState _shownState(CriticalAlarmState current) {
    if (showsRingingLayout(current)) {
      _lastRinging = current;
      return current;
    }
    final last = _lastRinging;
    if (last != null && _lockHold.mayShowOverLock) return last;
    _lastRinging = null;
    return current;
  }

  @override
  void dispose() {
    _lockHold.leave(widget.routeIncidentId);
    super.dispose();
  }

  /// The look this alarm is drawn in: the topic's own, or the phone's.
  ///
  /// Only an alarm that is ringing or acknowledged has one. The loading
  /// and failed screens, a setup test and the first tool alarm keep the
  /// standard look, and so does anything that goes wrong here: the alarm
  /// screen always draws.
  ///
  /// It is decided once per incident and held ([AlarmStyleLatch]): a plan
  /// read that lands while the phone rings does not recolour "I'm up" or
  /// resize the face under a reaching thumb.
  AlarmStyle _styleFor(CriticalAlarmState state) {
    if (!state.isLive && !state.isAcknowledged) {
      _lookLatch.release();
      return alarmStyleOf(null);
    }
    // Asked on every build and never held: which exits an alarm ends on
    // can be learned after its first frame, and a setup screen is never
    // drawn in another look.
    if (state.isPreview || state.ackedExits != AckedExits.incident) {
      return alarmStyleOf(null);
    }
    try {
      return alarmStyleOf(
        _lookLatch.styleFor(
          state.incident?.id,
          decide: () => getIt<AlarmStyleGate>().styleFor(
            state.topic.isEmpty ? null : state.topic,
          ),
        ),
      );
    } on Object catch (_) {
      return alarmStyleOf(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Another incident is on screen now, or this one rang again, so a
    // challenge opened before is left. It is not carried over, and nothing
    // is owed until "At my desk" is tapped again.
    return BlocListener<CriticalAlarmCubit, CriticalAlarmState>(
      listener: (context, state) {
        _ringingTopic = state.topic.isEmpty ? null : state.topic;
        _lockHold.show(
          incidentId: state.incident?.id,
          isRinging: showsRingingLayout(state),
        );
      },
      child: BlocListener<CriticalAlarmCubit, CriticalAlarmState>(
        listenWhen: (previous, current) =>
            previous.incident?.id != current.incident?.id ||
            (previous.isAcknowledged && !current.isAcknowledged),
        listener: (context, state) {
          // Ringing again: what was cleared for it is owed again.
          if (!state.isAcknowledged) {
            _clearedIncidentIds.remove(state.incident?.id);
          }
          _leaveChallenge();
        },
        child: _buildAlarm(context),
      ),
    );
  }

  Widget _buildAlarm(BuildContext context) {
    return BlocListener<CriticalAlarmCubit, CriticalAlarmState>(
      // The stamps and the sheet after an acknowledge wait for the server to
      // take it. A 409, or any incident another device answered, is not an
      // acknowledge made here and gets neither.
      listenWhen: (previous, current) =>
          countsAsConfirmedAck(previous: previous, current: current),
      listener: (context, state) {
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
      child: _buildAlarmView(context),
    );
  }

  Widget _buildAlarmView(BuildContext context) {
    return BlocConsumer<CriticalAlarmCubit, CriticalAlarmState>(
      // The tap is felt at once, before the server answers. An incident
      // another device answered gets no success haptic.
      listenWhen: (previous, current) =>
          !previous.isAcknowledged &&
          current.isAcknowledged &&
          !current.isHandledElsewhere,
      listener: (context, state) {
        AppHaptics.success();
        setState(() {
          _direction = AmbientDirection.push;
        });
      },
      builder: (context, current) {
        final state = _shownState(current);
        final colors = context.appColors;
        final brightness = Theme.of(context).brightness;
        // A look that cannot be drawn is the standard one for this build,
        // canvas and screen alike.
        final style = drawableAlarmStyle(
          _styleFor(state),
          base: colors,
          severity: state.severityMode,
          brightness: brightness,
        );
        final stage = state.isAcknowledged
            ? AlarmStage.acknowledged
            : AlarmStage.ringing;
        // While it rings, the shape behind the face goes when the face
        // does: a small phone at a large text size has no room for it.
        final isRinging = stage == AlarmStage.ringing && state.isLive;
        final profile = isRinging
            ? style.ringing.ambientFor(
                colors,
                brightness,
                drawsFace: _drawsRingingFace(context, state, style.ringing),
              )
            : style.lookOf(stage).ambient(colors, brightness);

        Widget content;
        if (state.isHandledElsewhere) {
          content = _HandledElsewhereView(state: state);
        } else if (!state.isLive && !state.isAcknowledged) {
          content = _noAlarmContent(context, state);
        } else {
          content = _liveContent(
            context,
            state: state,
            style: style,
            stage: stage,
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

/// Whether the ringing screen draws its face. Measuring the message must
/// never take the alarm screen down, so a sum that throws counts as a
/// face: the canvas is then the one it always was.
bool _drawsRingingFace(
  BuildContext context,
  CriticalAlarmState state,
  AlarmRingingLook look,
) {
  try {
    return RingingScreen.drawsFace(context, state: state, look: look);
  } on Object catch (_) {
    return true;
  }
}
