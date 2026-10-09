/// The wake-up challenges this build knows.
///
/// A challenge is a small task before the second stage of an acknowledge,
/// "At my desk". It never sits before "I'm up": the ring always stops with
/// one tap.
///
/// [id] is saved on phones under `topic_challenge.<topic>`, so a shipped id
/// never changes. An id this build does not know reads as no challenge.
enum ChallengeKind {
  /// Type the name of the topic the screen already shows.
  typeTopicName('type_topic_name'),

  /// Type the first words of the alert title the screen already shows.
  typeAlertTitle('type_alert_title'),

  /// Answer one developer-flavoured sum.
  opsMath('ops_math'),

  /// Rub the cover off a card and type the four digit code under it.
  scratchCard('scratch_card');

  const ChallengeKind(this.id);

  final String id;

  /// The kind saved as [id], or null for none, or for an id from a build
  /// that knows more kinds than this one.
  static ChallengeKind? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}
