import 'package:flutter/foundation.dart';

/// A thing a person can hold: the Hosted subscription or the Pro pack.
///
/// A third product later is one value here and one [HoldingSource].
enum Holding { hosted, pro }

/// Where one [Holding] stands on this install.
enum HoldingState {
  notHeld,

  /// A purchase went through at the store and the server has not confirmed
  /// it yet.
  pending,
  held,
}

/// Says where one [Holding] stands, and when that may have changed.
///
/// A source is the only code that reads the store, the relay's answer or a
/// developer switch for its holding. `Holdings` is its only reader.
abstract interface class HoldingSource {
  Holding get holding;

  /// The state right now. Cheap and synchronous.
  HoldingState get state;

  /// Fires when [state] may have changed. It may fire with no change.
  Listenable get changes;
}
