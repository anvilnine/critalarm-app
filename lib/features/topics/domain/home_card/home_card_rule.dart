import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart' show SeverityMode;
import 'package:critalarm/features/reliability/domain/attention_order.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/readiness_pips.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';

/// Picks what Home's dark card shows.
///
/// Walks [homeCardPriority] and builds the first kind whose condition holds.
/// The rule returns slots and values, never text.
HomeCardModel resolveHomeCard(HomeCardInput input) {
  for (final kind in homeCardPriority) {
    if (_holds(kind, input)) return _build(kind, input);
  }
  return _build(HomeCardKind.idle, input);
}

bool _holds(HomeCardKind kind, HomeCardInput i) => switch (kind) {
  HomeCardKind.loading => _isLoading(i),
  HomeCardKind.ringing => _isRinging(i),
  HomeCardKind.acknowledged => _isAcknowledged(i),
  HomeCardKind.handled => _isHandled(i),
  HomeCardKind.missed => _isMissed(i),
  HomeCardKind.noServer => _isNoServer(i),
  HomeCardKind.stale => _isStale(i),
  HomeCardKind.loadFailed => _isLoadFailed(i),
  HomeCardKind.noTopics => _isNoTopics(i),
  HomeCardKind.issueBroken => _isIssueBroken(i),
  HomeCardKind.issueLook => _isIssueLook(i),
  HomeCardKind.warning => _isWarning(i),
  HomeCardKind.setup => _isSetup(i),
  HomeCardKind.waiting => _isWaiting(i),
  HomeCardKind.quiet => _isQuiet(i),
  HomeCardKind.idle => true,
};

bool _isLoading(HomeCardInput i) => i.isLoading;

bool _isRinging(HomeCardInput i) => i.ringing != null;

/// The desk timer is still counting. Once the deadline passes the alarm rings
/// again and this card no longer applies.
bool _isAcknowledged(HomeCardInput i) {
  final fact = i.acknowledged;
  return fact != null && i.now.isBefore(fact.deadline);
}

bool _isHandled(HomeCardInput i) {
  final fact = i.handled;
  return fact != null && i.now.difference(fact.closedAt) < handledCardWindow;
}

bool _isMissed(HomeCardInput i) => i.missed != null;

bool _isNoServer(HomeCardInput i) => !i.hasServer;

bool _isStale(HomeCardInput i) => i.isStale;

bool _isLoadFailed(HomeCardInput i) => i.loadFailed;

bool _isNoTopics(HomeCardInput i) => i.topicCount == 0;

/// Health only counts once the first read has ended.
bool _isIssueBroken(HomeCardInput i) =>
    i.readiness.loaded &&
    i.readiness.checks.any((c) => c.state == ReliabilityState.broken);

bool _isIssueLook(HomeCardInput i) =>
    i.readiness.loaded &&
    (i.readiness.incomplete ||
        i.readiness.checks.any((c) => c.state == ReliabilityState.needsLook));

bool _isWarning(HomeCardInput i) => i.warningCount > 0;

/// Setup is on screen and unfinished, and more than the first message is
/// left to do.
bool _isSetup(HomeCardInput i) {
  final setup = i.setup;
  return setup != null &&
      setup.isVisible &&
      !setup.isComplete &&
      !_onlyFirstMessageOpen(setup);
}

bool _isWaiting(HomeCardInput i) {
  final setup = i.setup;
  return setup != null && setup.isVisible && _onlyFirstMessageOpen(setup);
}

bool _onlyFirstMessageOpen(SetupChecklist setup) =>
    setup.hasServer && setup.hasCriticalTopic && !setup.hasFirstMessage;

/// The newest message anywhere is older than [quietAfter]. With no message
/// on record there is nothing to be quiet about.
bool _isQuiet(HomeCardInput i) {
  final newest = i.newestMessageAt;
  return newest != null && i.now.difference(newest) > quietAfter;
}

HomeCardModel _build(HomeCardKind kind, HomeCardInput i) => switch (kind) {
  HomeCardKind.loading => _loading(),
  HomeCardKind.ringing => _ringing(i.ringing!),
  HomeCardKind.acknowledged => _acknowledged(i.acknowledged!),
  HomeCardKind.handled => _handled(i.handled!),
  HomeCardKind.missed => _missed(i.missed!),
  HomeCardKind.noServer => _noServer(),
  HomeCardKind.stale => _stale(i, kind),
  HomeCardKind.loadFailed => _stale(i, kind),
  HomeCardKind.noTopics => _noTopics(),
  HomeCardKind.issueBroken => _issue(i, kind),
  HomeCardKind.issueLook => _issue(i, kind),
  HomeCardKind.warning => _warning(i),
  HomeCardKind.setup => _setup(i),
  HomeCardKind.waiting => _waiting(i),
  HomeCardKind.quiet => _quiet(i),
  HomeCardKind.idle => _idle(i),
};

HomeCardModel _loading() => const HomeCardModel(
  kind: HomeCardKind.loading,
  label: HomeCardLabel.willItWakeMe,
  numeral: Dots(),
  foot: HomeCardFoot(HomeCardFootSlot.askingServer),
  face: FaceState.calm,
  severity: SeverityMode.none,
  discTone: HomeCardDiscTone.paleYellow,
  numeralTone: HomeCardNumeralTone.muted,
);

HomeCardModel _ringing(RingingFact fact) {
  final openedAt = fact.openedAt;
  return HomeCardModel(
    kind: HomeCardKind.ringing,
    label: HomeCardLabel.ringing,
    numeral: openedAt == null ? const Unknown() : Elapsed(openedAt),
    foot: HomeCardFoot(HomeCardFootSlot.topic, topic: fact.topic),
    action: OpenAlarm(fact.incidentId),
    face: FaceState.alarmed,
    severity: SeverityMode.crit,
    discTone: HomeCardDiscTone.red,
    numeralTone: HomeCardNumeralTone.redAlt,
  );
}

HomeCardModel _acknowledged(AcknowledgedFact fact) => HomeCardModel(
  kind: HomeCardKind.acknowledged,
  label: HomeCardLabel.ringsAgainIn,
  numeral: Remaining(fact.deadline),
  foot: HomeCardFoot(HomeCardFootSlot.topicUnlessClosed, topic: fact.topic),
  action: OpenIncident(fact.incidentId),
  face: FaceState.acked,
  severity: SeverityMode.ack,
  discTone: HomeCardDiscTone.cobalt,
  numeralTone: HomeCardNumeralTone.yellow,
);

HomeCardModel _handled(HandledFact fact) {
  final answeredAfter = fact.answeredAfter;
  return HomeCardModel(
    kind: HomeCardKind.handled,
    label: answeredAfter == null
        ? HomeCardLabel.closed
        : HomeCardLabel.answeredIn,
    numeral: answeredAfter == null
        ? At(fact.closedAt)
        : Seconds(answeredAfter.inSeconds),
    foot: HomeCardFoot(
      HomeCardFootSlot.topicClosedAt,
      topic: fact.topic,
      time: fact.closedAt,
    ),
    face: FaceState.happy,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.paleYellow,
    numeralTone: HomeCardNumeralTone.yellow,
  );
}

HomeCardModel _missed(MissedFact fact) {
  final duration = fact.ringDuration;
  return HomeCardModel(
    kind: HomeCardKind.missed,
    label: HomeCardLabel.missed,
    numeral: Number(fact.notice.count),
    foot: duration == null
        ? HomeCardFoot(HomeCardFootSlot.missedAt, time: fact.notice.at)
        : HomeCardFoot(
            HomeCardFootSlot.missedRang,
            duration: duration,
            time: fact.notice.at,
          ),
    action: const SeeMissed(),
    face: needsLookFace,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.redSoft,
    numeralTone: HomeCardNumeralTone.red,
  );
}

HomeCardModel _noServer() => const HomeCardModel(
  kind: HomeCardKind.noServer,
  label: HomeCardLabel.none,
  numeral: No(),
  foot: HomeCardFoot(HomeCardFootSlot.noServer),
  action: ConnectServer(),
  face: FaceState.sad,
  severity: SeverityMode.none,
  discTone: HomeCardDiscTone.redSoft,
  numeralTone: HomeCardNumeralTone.red,
);

/// The two kinds that share the stale slot: an old copy of the list, and no
/// copy at all.
HomeCardModel _stale(HomeCardInput i, HomeCardKind kind) {
  final lastGood = i.lastKnownGoodAt;
  final isStale = kind == HomeCardKind.stale;
  return HomeCardModel(
    kind: kind,
    label: isStale ? HomeCardLabel.serverLastSeen : HomeCardLabel.server,
    numeral: lastGood == null ? const Unknown() : At(lastGood),
    foot: HomeCardFoot(
      isStale ? HomeCardFootSlot.notAnswering : HomeCardFootSlot.couldNotLoad,
    ),
    action: const RetryLoad(),
    face: FaceState.watching,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.ink,
    numeralTone: HomeCardNumeralTone.muted,
  );
}

HomeCardModel _noTopics() => const HomeCardModel(
  kind: HomeCardKind.noTopics,
  label: HomeCardLabel.topics,
  numeral: Number(0),
  foot: HomeCardFoot(HomeCardFootSlot.nothingReachesYou),
  face: FaceState.interested,
  severity: SeverityMode.none,
  discTone: HomeCardDiscTone.paleYellow,
  numeralTone: HomeCardNumeralTone.muted,
);

/// Broken and needs-a-look share one layout. The foot names the worst check,
/// and the button is the fix of the first check that has one.
HomeCardModel _issue(HomeCardInput i, HomeCardKind kind) {
  final checks = i.readiness.checks;
  final count = readinessCount(checks);
  final isBroken = kind == HomeCardKind.issueBroken;
  final worst = worstCheck(checks);
  final fixOf = checkToFix(checks)?.fix;
  // A read with a hole in it says so, unless a check is known to be broken.
  final foot = !isBroken && i.readiness.incomplete
      ? const HomeCardFoot(HomeCardFootSlot.checkCouldNotRun)
      : HomeCardFoot(
          HomeCardFootSlot.worstCheck,
          checkId: worst?.id,
          reason: worst?.reason,
        );
  return HomeCardModel(
    kind: kind,
    label: HomeCardLabel.willItWakeMe,
    numeral: Count(count.fine, count.total),
    pips: pipsFor(checks),
    foot: foot,
    action: fixOf == null ? null : Fix(fixOf),
    face: isBroken ? brokenFace : needsLookFace,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.orangeSoft,
    numeralTone: isBroken
        ? HomeCardNumeralTone.redAlt
        : HomeCardNumeralTone.orange,
    tapsReliability: true,
  );
}

HomeCardModel _warning(HomeCardInput i) => HomeCardModel(
  kind: HomeCardKind.warning,
  label: HomeCardLabel.needsALook,
  numeral: Number(i.warningCount),
  foot: const HomeCardFoot(HomeCardFootSlot.warningTopics),
  face: FaceState.worried,
  severity: SeverityMode.high,
  discTone: HomeCardDiscTone.orange,
  numeralTone: HomeCardNumeralTone.orangeAlt,
);

/// The first setup row that is not done, or null when all are.
SetupChecklistRow? _nextOpenRow(SetupChecklist setup) {
  for (final row in SetupChecklistRow.values) {
    if (!setup.isTicked(row)) return row;
  }
  return null;
}

HomeCardModel _setup(HomeCardInput i) {
  final setup = i.setup!;
  final next = _nextOpenRow(setup);
  final route = next == null
      ? null
      : setupChecklistRoute(
          next,
          checklist: setup,
          firstTopic: i.firstTopic,
          watchedTopic: i.watchedTopic,
        );
  return HomeCardModel(
    kind: HomeCardKind.setup,
    label: HomeCardLabel.setup,
    numeral: Count(setup.tickedCount, SetupChecklistRow.values.length),
    pips: [
      for (final row in SetupChecklistRow.values)
        setup.isTicked(row) ? PipTone.fine : PipTone.open,
    ],
    foot: HomeCardFoot(HomeCardFootSlot.setupNext, setupRow: next),
    action: route == null ? null : ContinueSetup(route),
    face: FaceState.calm,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.paleYellow,
    numeralTone: HomeCardNumeralTone.yellow,
  );
}

HomeCardModel _waiting(HomeCardInput i) {
  final topic = i.watchedTopic;
  return HomeCardModel(
    kind: HomeCardKind.waiting,
    label: HomeCardLabel.firstMessage,
    numeral: const NotYet(),
    foot: const HomeCardFoot(HomeCardFootSlot.sendTheLine),
    action: topic == null ? null : GetFirstLine(topic),
    face: FaceState.watching,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.paleYellow,
    numeralTone: HomeCardNumeralTone.muted,
  );
}

HomeCardFoot _lastAlarmFoot(HomeCardInput i) {
  final last = i.lastAlarmAt;
  return last == null
      ? const HomeCardFoot(HomeCardFootSlot.noAlarmYet)
      : HomeCardFoot(HomeCardFootSlot.lastAlarm, time: last);
}

HomeCardModel _quiet(HomeCardInput i) => HomeCardModel(
  kind: HomeCardKind.quiet,
  label: HomeCardLabel.quietFor,
  numeral: Days(i.now.difference(i.newestMessageAt!).inDays),
  foot: _lastAlarmFoot(i),
  // The test goes through the server, which refuses it when no topic has
  // Critical delivery on.
  action: i.hasCriticalTopic ? const SendTest() : null,
  face: FaceState.dozing,
  severity: SeverityMode.none,
  discTone: HomeCardDiscTone.ink,
  numeralTone: HomeCardNumeralTone.yellow,
);

HomeCardModel _idle(HomeCardInput i) {
  final readiness = i.readiness;
  final HomeCardNumeral numeral;
  if (!readiness.loaded) {
    numeral = const Dots();
  } else {
    final count = readinessCount(readiness.checks);
    numeral = count.total == 0
        ? const Unknown()
        : Count(count.fine, count.total);
  }
  return HomeCardModel(
    kind: HomeCardKind.idle,
    label: HomeCardLabel.willItWakeMe,
    numeral: numeral,
    pips: readiness.loaded ? pipsFor(readiness.checks) : const [],
    foot: i.hasCriticalTopic
        ? _lastAlarmFoot(i)
        : const HomeCardFoot(HomeCardFootSlot.noTopicRings),
    face: FaceState.calm,
    severity: SeverityMode.none,
    discTone: HomeCardDiscTone.paleYellow,
    numeralTone: HomeCardNumeralTone.yellow,
    tapsReliability: true,
  );
}
