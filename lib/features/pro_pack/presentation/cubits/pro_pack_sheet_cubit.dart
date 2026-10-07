import 'dart:async';

import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> _realWait(Duration d) => Future<void>.delayed(d);

/// Runs the Pro sheet: what the store offers, a purchase, a restore, and the
/// wait for the relay to say the pack is held.
///
/// Whether the pack is held is always the relay's answer, through
/// [ProPackAccess]. The store finishing a purchase only starts the asking.
/// An answer that says nothing (`confirmed: false` with no pack listed, a
/// call that failed, the local limit) is a reason to ask again and never a
/// reason to say the purchase failed or the pack is missing.
class ProPackSheetCubit extends Cubit<ProPackSheetState> {
  ProPackSheetCubit({
    required this._access,
    required this._shop,
    this._analytics,
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? _realWait,
       super(const ProPackSheetState()) {
    _stopListening = _access.stream.listen((isHeld) {
      if (isHeld) _show(ProPackSheetStage.held);
    }).cancel;
  }

  /// The waits before each ask the sheet makes on its own after the store
  /// finishes. Five asks, which stays under the relay's limit for one
  /// minute (api.md §4.2).
  static const confirmWaits = <Duration>[
    Duration.zero,
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 24),
  ];

  final ProPackAccess _access;
  final ProPackShop _shop;
  final ProPackAnalytics? _analytics;
  final Future<void> Function(Duration) _wait;

  /// Stops hearing [ProPackAccess] when the sheet closes.
  late final Future<void> Function() _stopListening;

  /// Whether the last trip to the store was a purchase, for the retry.
  bool _afterPurchase = false;

  void _show(
    ProPackSheetStage stage, {
    ProPackSheetNote? note,
    List<ProPackOffer>? offers,
  }) {
    if (isClosed) return;
    emit(
      ProPackSheetState(
        stage: stage,
        offers: offers ?? state.offers,
        note: note,
      ),
    );
  }

  /// Called once when the sheet opens.
  Future<void> open(ProPackSheetSource source) async {
    unawaited(_analytics?.sheetOpened(source));
    if (_access.isHeld) return _show(ProPackSheetStage.held);
    final offers = await _shop.readOffers();
    if (isClosed || state.stage != ProPackSheetStage.loading) return;
    _show(_restingStage(offers), offers: offers);
  }

  /// Where the sheet rests when nothing is running: the offers, or the
  /// line that says there are none.
  ProPackSheetStage _restingStage(List<ProPackOffer> offers) =>
      offers.isEmpty ? ProPackSheetStage.notOnSale : ProPackSheetStage.offers;

  /// Restore is there whenever the sheet rests and the pack is not held,
  /// with or without anything on sale. It is gone only while the store or
  /// the relay is being asked.
  static bool canRestore(ProPackSheetStage stage) => switch (stage) {
    ProPackSheetStage.notOnSale ||
    ProPackSheetStage.offers ||
    ProPackSheetStage.checkingPaused => true,
    ProPackSheetStage.loading ||
    ProPackSheetStage.atStore ||
    ProPackSheetStage.checking ||
    ProPackSheetStage.held => false,
  };

  Future<void> buy(ProPackOffer offer) async {
    if (state.stage != ProPackSheetStage.offers) return;
    _show(ProPackSheetStage.atStore);
    // Written down before the store is asked, so a purchase the app does
    // not live to see confirmed is asked about again on the next launch.
    await _access.purchaseStarted();
    final result = await _shop.buy(offer);
    if (result == ProPackStoreResult.cancelled) {
      await _access.purchaseAbandoned();
    }
    await _afterStore(result, afterPurchase: true);
  }

  Future<void> restore() async {
    if (!canRestore(state.stage)) return;
    _show(ProPackSheetStage.atStore);
    final result = await _shop.restore();
    await _afterStore(result, afterPurchase: false);
  }

  /// The button on the paused state. Runs the same asks again.
  Future<void> checkAgain() async {
    if (state.stage != ProPackSheetStage.checkingPaused) return;
    await _confirm(afterPurchase: _afterPurchase, report: false);
  }

  Future<void> _afterStore(
    ProPackStoreResult result, {
    required bool afterPurchase,
  }) async {
    if (isClosed || state.stage == ProPackSheetStage.held) return;
    switch (result) {
      case ProPackStoreResult.cancelled:
        _show(_restingStage(state.offers));
      case ProPackStoreResult.problem:
        _show(
          _restingStage(state.offers),
          note: ProPackSheetNote.storeProblem,
        );
      case ProPackStoreResult.done:
        await _confirm(afterPurchase: afterPurchase, report: true);
    }
  }

  /// Asks the relay until it says the pack is held, or the tries run out.
  Future<void> _confirm({
    required bool afterPurchase,
    required bool report,
  }) async {
    _afterPurchase = afterPurchase;
    _show(ProPackSheetStage.checking);
    var result = 'checking';
    for (final delay in confirmWaits) {
      if (delay > Duration.zero) await _wait(delay);
      if (isClosed) return;
      if (_access.isHeld) {
        result = 'held';
        break;
      }
      final outcome = await _access.confirmWithStore();
      if (isClosed) return;
      if (outcome == ProPackRefreshOutcome.held) {
        result = 'held';
        break;
      }
      // After a restore, a store that was read and holds nothing is a real
      // answer. After a purchase the store has just taken one, so the same
      // answer only means the relay has not seen it yet: ask again.
      if (outcome == ProPackRefreshOutcome.notHeld && !afterPurchase) {
        result = 'none';
        break;
      }
    }
    // The relay can answer through another door while the last ask is out.
    if (_access.isHeld) result = 'held';
    if (report) {
      unawaited(
        afterPurchase
            ? _analytics?.purchaseFinished(result: result)
            : _analytics?.restoreFinished(result: result),
      );
    }
    switch (result) {
      case 'held':
        _show(ProPackSheetStage.held);
      case 'none':
        _show(
          _restingStage(state.offers),
          note: ProPackSheetNote.nothingToRestore,
        );
      default:
        _show(ProPackSheetStage.checkingPaused);
    }
  }

  @override
  Future<void> close() async {
    await _stopListening();
    return super.close();
  }
}
