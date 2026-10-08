import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart' show SeverityMode;
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/readiness_pips.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter/foundation.dart';

/// The small mono line above the numeral. A slot, not a string: the words
/// come from the view.
enum HomeCardLabel {
  /// No label is drawn.
  none,
  willItWakeMe,
  ringing,
  ringsAgainIn,
  answeredIn,

  /// The handled card when the time to answer is not known.
  closed,
  missed,
  serverLastSeen,
  server,
  topics,
  needsALook,
  setup,
  firstMessage,
  quietFor,
}

/// The big figure. A value the view formats.
@immutable
sealed class HomeCardNumeral {
  const HomeCardNumeral();
}

/// Three dots: nothing is known yet.
final class Dots extends HomeCardNumeral {
  const Dots();

  @override
  bool operator ==(Object other) => other is Dots;

  @override
  int get hashCode => (Dots).hashCode;
}

/// "No", for no server.
final class No extends HomeCardNumeral {
  const No();

  @override
  bool operator ==(Object other) => other is No;

  @override
  int get hashCode => (No).hashCode;
}

/// A question mark: the value cannot be known.
final class Unknown extends HomeCardNumeral {
  const Unknown();

  @override
  bool operator ==(Object other) => other is Unknown;

  @override
  int get hashCode => (Unknown).hashCode;
}

/// "Not yet".
final class NotYet extends HomeCardNumeral {
  const NotYet();

  @override
  bool operator ==(Object other) => other is NotYet;

  @override
  int get hashCode => (NotYet).hashCode;
}

/// [done] of [of], such as 6 of 7 checks or 1 of 3 setup rows.
final class Count extends HomeCardNumeral {
  const Count(this.done, this.of);

  final int done;
  final int of;

  @override
  bool operator ==(Object other) =>
      other is Count && other.done == done && other.of == of;

  @override
  int get hashCode => Object.hash(Count, done, of);

  @override
  String toString() => 'Count($done/$of)';
}

/// A plain count.
final class Number extends HomeCardNumeral {
  const Number(this.n);

  final int n;

  @override
  bool operator ==(Object other) => other is Number && other.n == n;

  @override
  int get hashCode => Object.hash(Number, n);

  @override
  String toString() => 'Number($n)';
}

/// A length of time in seconds.
final class Seconds extends HomeCardNumeral {
  const Seconds(this.n);

  final int n;

  @override
  bool operator ==(Object other) => other is Seconds && other.n == n;

  @override
  int get hashCode => Object.hash(Seconds, n);

  @override
  String toString() => 'Seconds($n)';
}

/// A length of time in whole days.
final class Days extends HomeCardNumeral {
  const Days(this.n);

  final int n;

  @override
  bool operator ==(Object other) => other is Days && other.n == n;

  @override
  int get hashCode => Object.hash(Days, n);

  @override
  String toString() => 'Days($n)';
}

/// Time passed since [since]. The view ticks it.
final class Elapsed extends HomeCardNumeral {
  const Elapsed(this.since);

  final DateTime since;

  @override
  bool operator ==(Object other) => other is Elapsed && other.since == since;

  @override
  int get hashCode => Object.hash(Elapsed, since);

  @override
  String toString() => 'Elapsed($since)';
}

/// Time left until [until].
final class Remaining extends HomeCardNumeral {
  const Remaining(this.until);

  final DateTime until;

  @override
  bool operator ==(Object other) => other is Remaining && other.until == until;

  @override
  int get hashCode => Object.hash(Remaining, until);

  @override
  String toString() => 'Remaining($until)';
}

/// A moment, drawn as a time.
final class At extends HomeCardNumeral {
  const At(this.time);

  final DateTime time;

  @override
  bool operator ==(Object other) => other is At && other.time == time;

  @override
  int get hashCode => Object.hash(At, time);

  @override
  String toString() => 'At($time)';
}

/// The text slot of the line under the numeral.
enum HomeCardFootSlot {
  askingServer,

  /// [HomeCardFoot.topic].
  topic,

  /// [HomeCardFoot.topic], and the alarm rings again unless closed.
  topicUnlessClosed,

  /// [HomeCardFoot.topic] and [HomeCardFoot.time].
  topicClosedAt,

  /// [HomeCardFoot.duration] and [HomeCardFoot.time].
  missedRang,

  /// [HomeCardFoot.time] only, for a ring time that is not known.
  missedAt,
  noServer,
  notAnswering,
  couldNotLoad,
  nothingReachesYou,

  /// [HomeCardFoot.checkId] and [HomeCardFoot.reason].
  worstCheck,
  checkCouldNotRun,
  warningTopics,

  /// [HomeCardFoot.setupRow].
  setupNext,
  sendTheLine,

  /// [HomeCardFoot.time].
  lastAlarm,
  noAlarmYet,
  noTopicRings,
}

/// The line under the numeral: a slot and the values the slot needs.
@immutable
class HomeCardFoot {
  const HomeCardFoot(
    this.slot, {
    this.topic,
    this.time,
    this.duration,
    this.checkId,
    this.reason,
    this.setupRow,
  });

  final HomeCardFootSlot slot;
  final String? topic;
  final DateTime? time;
  final Duration? duration;
  final ReliabilityCheckId? checkId;
  final String? reason;
  final SetupChecklistRow? setupRow;

  @override
  bool operator ==(Object other) =>
      other is HomeCardFoot &&
      other.slot == slot &&
      other.topic == topic &&
      other.time == time &&
      other.duration == duration &&
      other.checkId?.value == checkId?.value &&
      other.reason == reason &&
      other.setupRow == setupRow;

  @override
  int get hashCode => Object.hash(
    slot,
    topic,
    time,
    duration,
    checkId?.value,
    reason,
    setupRow,
  );

  @override
  String toString() => 'HomeCardFoot(${slot.name})';
}

/// What the card's button does. Data only: the screen runs it.
@immutable
sealed class HomeCardAction {
  const HomeCardAction();
}

/// Open the alarm screen of an incident that is ringing.
final class OpenAlarm extends HomeCardAction {
  const OpenAlarm(this.incidentId);

  final String incidentId;

  @override
  bool operator ==(Object other) =>
      other is OpenAlarm && other.incidentId == incidentId;

  @override
  int get hashCode => Object.hash(OpenAlarm, incidentId);
}

/// Open the incident page.
final class OpenIncident extends HomeCardAction {
  const OpenIncident(this.incidentId);

  final String incidentId;

  @override
  bool operator ==(Object other) =>
      other is OpenIncident && other.incidentId == incidentId;

  @override
  int get hashCode => Object.hash(OpenIncident, incidentId);
}

/// Open the missed alarm.
final class SeeMissed extends HomeCardAction {
  const SeeMissed();

  @override
  bool operator ==(Object other) => other is SeeMissed;

  @override
  int get hashCode => (SeeMissed).hashCode;
}

/// Open the connect-a-server flow.
final class ConnectServer extends HomeCardAction {
  const ConnectServer();

  @override
  bool operator ==(Object other) => other is ConnectServer;

  @override
  int get hashCode => (ConnectServer).hashCode;
}

/// Ask the server again.
final class RetryLoad extends HomeCardAction {
  const RetryLoad();

  @override
  bool operator ==(Object other) => other is RetryLoad;

  @override
  int get hashCode => (RetryLoad).hashCode;
}

/// Run the fix of a reliability check.
final class Fix extends HomeCardAction {
  const Fix(this.fix);

  final ReliabilityFix fix;

  @override
  bool operator ==(Object other) => other is Fix && other.fix == fix;

  @override
  int get hashCode => Object.hash(Fix, fix);
}

/// Go on with setup at [route].
final class ContinueSetup extends HomeCardAction {
  const ContinueSetup(this.route);

  final String route;

  @override
  bool operator ==(Object other) =>
      other is ContinueSetup && other.route == route;

  @override
  int get hashCode => Object.hash(ContinueSetup, route);
}

/// Open the token and curl line of [topic].
final class GetFirstLine extends HomeCardAction {
  const GetFirstLine(this.topic);

  final String topic;

  @override
  bool operator ==(Object other) =>
      other is GetFirstLine && other.topic == topic;

  @override
  int get hashCode => Object.hash(GetFirstLine, topic);
}

/// Open the screen that asks the server to send a test alarm. The card never
/// rings anything itself.
final class SendTest extends HomeCardAction {
  const SendTest();

  @override
  bool operator ==(Object other) => other is SendTest;

  @override
  int get hashCode => (SendTest).hashCode;
}

/// The tint of the disc behind the face.
enum HomeCardDiscTone {
  paleYellow,
  ink,
  orangeSoft,
  orange,
  redSoft,
  red,
  cobalt,
}

/// The colour of the numeral on the dark card.
enum HomeCardNumeralTone {
  yellow,
  muted,
  orange,
  orangeAlt,
  red,
  redAlt,
}

/// Everything the Home card draws, as values.
@immutable
class HomeCardModel {
  const HomeCardModel({
    required this.kind,
    required this.label,
    required this.numeral,
    required this.foot,
    required this.face,
    required this.severity,
    required this.discTone,
    required this.numeralTone,
    this.pips = const [],
    this.action,
    this.tapsReliability = false,
  });

  final HomeCardKind kind;
  final HomeCardLabel label;
  final HomeCardNumeral numeral;
  final HomeCardFoot foot;

  /// One pip per readiness check, or one per setup row. Empty for the rest.
  final List<PipTone> pips;

  /// The button, or null when the card has none.
  final HomeCardAction? action;

  final FaceState face;
  final SeverityMode severity;
  final HomeCardDiscTone discTone;
  final HomeCardNumeralTone numeralTone;

  /// A tap on the card body opens the reliability screen.
  final bool tapsReliability;

  @override
  bool operator ==(Object other) =>
      other is HomeCardModel &&
      other.kind == kind &&
      other.label == label &&
      other.numeral == numeral &&
      other.foot == foot &&
      listEquals(other.pips, pips) &&
      other.action == action &&
      other.face == face &&
      other.severity == severity &&
      other.discTone == discTone &&
      other.numeralTone == numeralTone &&
      other.tapsReliability == tapsReliability;

  @override
  int get hashCode => Object.hash(
    kind,
    label,
    numeral,
    foot,
    Object.hashAll(pips),
    action,
    face,
    severity,
    discTone,
    numeralTone,
    tapsReliability,
  );

  @override
  String toString() => 'HomeCardModel(${kind.name}, $numeral)';
}
