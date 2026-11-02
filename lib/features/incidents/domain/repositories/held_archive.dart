import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';

/// What the phone already holds of the alarms and messages, read without a
/// request.
///
/// Every read answers for the account the phone is on now and for no other.
/// A phone that holds nothing, a store that will not open and a read that
/// fails all answer with nothing, so a caller never has to tell them apart.
abstract interface class HeldArchive {
  /// The newest incidents held, newest first. An incident is open here only
  /// when the last answer the phone stored for it said so.
  Future<List<Incident>> heldIncidents({required int limit});

  /// How many incidents sit before [bound]. Zero for a null [bound].
  Future<int> heldIncidentsBefore(DateTime? bound);

  /// The newest messages held for [topic], newest first.
  Future<List<Message>> heldMessages(String topic, {required int limit});
}
