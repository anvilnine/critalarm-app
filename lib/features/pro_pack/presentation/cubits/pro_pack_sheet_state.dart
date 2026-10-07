import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:flutter/foundation.dart';

/// What the Pro sheet is showing.
enum ProPackSheetStage {
  /// Asking the store what is on sale.
  loading,

  /// Nothing to buy: no offering, or a build that skips the store. Restore
  /// is still there.
  notOnSale,

  /// The store's packages, each one tappable, and Restore.
  offers,

  /// The store is busy with a purchase or a restore.
  atStore,

  /// The store finished and the relay has not said the pack is held yet.
  /// The sheet is asking again on its own.
  checking,

  /// Still not known after the tries the sheet makes on its own. It offers
  /// one button to ask again. Never worded as a failure.
  checkingPaused,

  /// The store is holding the payment: it waits for an approval or for the
  /// money. Nothing failed and nothing is held yet. The sheet offers one
  /// button to ask again and nothing to buy, so a tap never goes back to
  /// the store.
  paymentPending,

  /// The install holds the pack.
  held,
}

/// A one-line note under the top of the sheet.
enum ProPackSheetNote {
  /// The store reported a problem of its own.
  storeProblem,

  /// A restore finished, the store was read, and there was nothing on it.
  nothingToRestore,
}

@immutable
final class ProPackSheetState {
  const ProPackSheetState({
    this.stage = ProPackSheetStage.loading,
    this.offers = const [],
    this.note,
  });

  final ProPackSheetStage stage;
  final List<ProPackOffer> offers;
  final ProPackSheetNote? note;

  @override
  bool operator ==(Object other) =>
      other is ProPackSheetState &&
      other.stage == stage &&
      listEquals(other.offers, offers) &&
      other.note == note;

  @override
  int get hashCode => Object.hash(stage, Object.hashAll(offers), note);

  @override
  String toString() =>
      'ProPackSheetState($stage, offers: ${offers.length}, note: $note)';
}
