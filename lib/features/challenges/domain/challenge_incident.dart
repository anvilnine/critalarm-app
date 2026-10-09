import 'package:flutter/foundation.dart';

/// What a challenge may know about the alarm it runs for: the words the
/// acknowledged screen already shows, and nothing else.
///
/// A challenge compares what a person does with these strings. It never
/// reads a message, and nothing here is sent anywhere.
@immutable
final class ChallengeIncident {
  const ChallengeIncident({required this.topic, this.alertTitle});

  /// The topic name, as the pill under the title shows it.
  final String topic;

  /// The alert title on screen, or null when the screen shows none.
  final String? alertTitle;

  @override
  bool operator ==(Object other) =>
      other is ChallengeIncident &&
      other.topic == topic &&
      other.alertTitle == alertTitle;

  @override
  int get hashCode => Object.hash(topic, alertTitle);

  @override
  String toString() => 'ChallengeIncident($topic)';
}
