part of 'critical_alarm_screen.dart';

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
    final is24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final startedLabel = startedAt != null
        ? formatClock(startedAt, is24Hour: is24Hour, withSeconds: true)
        : '';
    final ackedLabel = ackedAt != null
        ? formatClock(ackedAt, is24Hour: is24Hour, withSeconds: true)
        : '';
    final ackedSub = LocaleKeys.critical_alarm_acked_sub.tr(
      namedArgs: {
        'duration': ringDuration == null
            ? ''
            : formatRingDuration(ringDuration),
      },
    );
    // The demo welcomes: a ripple of happy faces, the title and one line,
    // with confetti on top.
    final faceState = state.faceState;
    final style = AlarmStyleScope.of(context);
    final look = style.acknowledged;

    final size = AppSize.of(context);
    // A fold splits the screen at the fold instead, so neither the wide row
    // nor the upright column runs across it.
    final fold = AppFold.of(context);
    final isWide = fold.isNone && (size.isExpanded || size.isShort);
    final isClosed = state.status == CriticalAlarmStatus.closed;
    // The hint is pinned over At my desk. At a large text size it runs to
    // several lines and the pinned block would take half a small screen,
    // so it goes into the list, under the details card. At 1.3 it already
    // takes two lines and hides the last row of the card, so it moves there
    // from 1.3 on. In the end pane of a book fold it is always in the list,
    // with the card, so the pane's room never rests on a guess at how many
    // lines it takes.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final pinsHint = textScale < 1.3 && !fold.isBook;
    final hintInList = !isClosed && !pinsHint;

    final exitButtons = _bottomBar(
      context,
      exits: exits,
      setupTest: setupTest,
      look: look,
      isClosed: isClosed,
      pinsHint: pinsHint,
    );

    // After a test on an iPhone, "Loud enough?" sits above the exits.
    final loudnessRetry = state.isPreview
        ? null
        : loudnessAskFor(
            isIos: getIt<PlatformCapabilities>().isIos,
            exits: exits,
            isTestIncident: incident != null && IncidentKinds.isTest(incident),
          );
    final bottomBar = loudnessRetry == null
        ? exitButtons
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoudEnoughAsk(
                key: ValueKey('loud-enough-${incident?.id}'),
                retry: loudnessRetry,
                setupTest: setupTest,
                incidentId: incident?.id ?? '',
                textColor: colors.onCanvas,
              ),
              exitButtons,
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
        exits: exits,
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

    if (!fold.isNone) {
      return _folded(
        context,
        fold,
        look,
        bottomBar,
        ackedSub: ackedSub,
        startedLabel: startedLabel,
        ackedLabel: ackedLabel,
        hintInList: hintInList,
        isClosed: isClosed,
      );
    }

    if (isWide) {
      return _wideLayout(
        context,
        look: look,
        bottomBar: bottomBar,
        faceState: faceState,
        ackedSub: ackedSub,
        startedLabel: startedLabel,
        ackedLabel: ackedLabel,
        hintInList: hintInList,
        isClosed: isClosed,
        pinsHint: pinsHint,
      );
    }

    return _portraitLayout(
      context,
      look: look,
      bottomBar: bottomBar,
      faceState: faceState,
      textScale: textScale,
      ackedSub: ackedSub,
      startedLabel: startedLabel,
      ackedLabel: ackedLabel,
      hintInList: hintInList,
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

  /// The part of [_restHeight] that is lines of text (the line under the
  /// title, the three rows of the card and the hint), which grows with the
  /// text size while the rest stays put.
  static const double _restTextHeight = 120;
  static const double _minFace = 88;

  /// One line on any phone at the default text size: the type scales down
  /// until the word fits, and it never breaks inside a word.
  Widget _title(AlarmAcknowledgedLook look, TextAlign align) {
    return AppFittedTitle(
      LocaleKeys.critical_alarm_acked_title.tr(),
      textAlign: align,
      style: look.type.title.copyWith(color: colors.onCanvas),
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
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
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

  Widget _sub(AlarmAcknowledgedLook look, TextAlign align, String text) {
    return Text(
      text,
      textAlign: align,
      style: look.type.line.copyWith(color: colors.onCanvas),
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
