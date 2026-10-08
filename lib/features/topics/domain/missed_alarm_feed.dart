import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';

/// The missed alarm entry for Home's card.
///
/// It answers the same question as the missed alarm notice and shares its
/// rule and its record of closed entries, but it does not go through the
/// notice slot. A health notice that wins the slot cannot hide a missed alarm
/// from the card, and the notice's cooldown does not delay it.
///
/// It only reads, and closes entries. It rings nothing and posts nothing.
abstract interface class MissedAlarmFeed {
  /// The newest missed alarm and how many there are, or null when there is
  /// nothing to show: setup is not done, no alarm was missed in the last
  /// week, every one was closed, or the read failed.
  Future<MissedFact?> read();

  /// Fires when what [read] returns may have changed: an alarm ran out, or an
  /// entry was closed through [dismiss].
  Stream<void> get changes;

  /// Closes the entry for [incidentIds] for good. It writes the same record
  /// the notice writes, so both views drop the entry.
  Future<void> dismiss(Iterable<String> incidentIds);
}
