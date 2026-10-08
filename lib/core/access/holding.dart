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

  /// The source could not read what it needs, and has no earlier answer to
  /// stand on. Nobody knows whether the holding is held.
  ///
  /// While a holding is here nothing is taken away and nothing is sold: it
  /// does not count as held, and it does not count as not held either.
  unknown,
}

/// Thrown by the "once ready" asks when a holding is [HoldingState.unknown].
///
/// The caller decides what "nobody knows" means for it, and the answer is
/// never to remove, lock, trim or offer something: keep what is on screen,
/// skip the write, count the person as paying.
final class HoldingUnreadable implements Exception {
  const HoldingUnreadable(this.holding);

  final Holding holding;

  @override
  String toString() => 'HoldingUnreadable(${holding.name})';
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

  /// Done once [state] is current: the first read has landed and no later
  /// one is still out. Never fails.
  ///
  /// Until then [state] may say `notHeld` for something that is held, so
  /// code that takes something away waits for this first.
  ///
  /// A source whose last read failed reads again when this is asked, so a
  /// read that failed once (a locked Keychain on a background launch) is
  /// tried again by the next caller. When it completes, [state] can still
  /// be [HoldingState.unknown].
  Future<void> get ready;
}
