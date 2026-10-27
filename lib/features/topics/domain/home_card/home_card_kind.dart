/// Which fact Home's dark card shows. The card shows exactly one.
enum HomeCardKind {
  /// The list has not answered yet.
  loading,

  /// An alarm is sounding.
  ringing,

  /// An alarm was acknowledged and its desk timer is counting down.
  acknowledged,

  /// An alarm was closed a moment ago.
  handled,

  /// An alarm ran out with nobody answering.
  missed,

  /// No server is saved.
  noServer,

  /// The server stopped answering and the list is an old copy.
  stale,

  /// A server is saved and the list never loaded, so there is no old copy.
  loadFailed,

  /// The server is fine and holds no topics.
  noTopics,

  /// A reliability check is broken: an alarm will not ring.
  issueBroken,

  /// A reliability check needs a look, or a source could not answer.
  issueLook,

  /// A topic sent a warning.
  warning,

  /// Setup is not finished.
  setup,

  /// Setup is finished except for the first message.
  waiting,

  /// No topic has received a message for a long while.
  quiet,

  /// Nothing needs saying.
  idle,
}

/// The order the card picks its kind in: the first kind whose condition
/// holds wins. This list is the only place the order is written, so a change
/// of order is a one-line edit here.
///
/// Z's proposed order, with the kinds the proposal does not list placed
/// beside the nearest one: `loading` outranks everything, `handled` sits
/// under `acknowledged`, `noTopics` under the server kinds, and `loadFailed`
/// shares the slot of `stale`. Broken and needs-a-look are both the
/// proposal's "possible issue" and keep its single slot, broken first.
const List<HomeCardKind> homeCardPriority = [
  HomeCardKind.loading,
  HomeCardKind.ringing,
  HomeCardKind.acknowledged,
  HomeCardKind.handled,
  HomeCardKind.missed,
  HomeCardKind.noServer,
  HomeCardKind.stale,
  HomeCardKind.loadFailed,
  HomeCardKind.noTopics,
  HomeCardKind.issueBroken,
  HomeCardKind.issueLook,
  HomeCardKind.warning,
  HomeCardKind.setup,
  HomeCardKind.waiting,
  HomeCardKind.quiet,
  HomeCardKind.idle,
];
