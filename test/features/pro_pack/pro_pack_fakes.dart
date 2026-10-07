import 'dart:async';

import 'package:critalarm/core/api/packs_api.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';

const proPack = AccountPack(id: 'pro');

/// A relay that answers what the test scripted, and counts the calls.
class FakePacksApi implements PacksApi {
  /// What `GET /relay/v1/packs` answers. Null throws, as no network does.
  PacksAnswer? packs = const PacksAnswer(packs: []);

  /// What each `POST /relay/v1/packs/refresh` answers, in order. The last
  /// one repeats. A null entry throws.
  List<PacksRefreshAnswer?> refreshes = [];

  int reads = 0;
  int refreshCalls = 0;

  @override
  Future<PacksAnswer> getPacks() async {
    reads++;
    final answer = packs;
    if (answer == null) throw Exception('no network');
    return answer;
  }

  @override
  Future<PacksRefreshAnswer> refreshPacks() async {
    final index = refreshCalls < refreshes.length
        ? refreshCalls
        : refreshes.length - 1;
    refreshCalls++;
    final answer = index < 0 ? null : refreshes[index];
    if (answer == null) throw Exception('no network');
    return answer;
  }
}

/// A relay whose answers the test hands over one by one, so it can decide
/// which call comes back first.
class GatedPacksApi implements PacksApi {
  final List<Completer<PacksAnswer>> reads = [];
  final List<Completer<PacksRefreshAnswer>> refreshes = [];

  @override
  Future<PacksAnswer> getPacks() {
    final gate = Completer<PacksAnswer>();
    reads.add(gate);
    return gate.future;
  }

  @override
  Future<PacksRefreshAnswer> refreshPacks() {
    final gate = Completer<PacksRefreshAnswer>();
    refreshes.add(gate);
    return gate.future;
  }
}

/// Lets everything that is ready to run, run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class MemoryProPackStore implements ProPackStore {
  MemoryProPackStore([this.kept]);

  StoredPacks? kept;
  int writes = 0;

  @override
  StoredPacks? read() => kept;

  @override
  Future<void> write(StoredPacks packs) async {
    writes++;
    kept = packs;
  }

  @override
  Future<void> clear() async => kept = null;

  PendingProPackConfirm? pending;

  @override
  PendingProPackConfirm? readPending() => pending;

  @override
  Future<void> writePending(PendingProPackConfirm pending) async =>
      this.pending = pending;

  @override
  Future<void> clearPending() async => pending = null;
}

class FakeProPackShop implements ProPackShop {
  FakeProPackShop({this.offers = const []});

  List<ProPackOffer> offers;
  ProPackStoreResult buyResult = ProPackStoreResult.done;
  ProPackStoreResult restoreResult = ProPackStoreResult.done;
  final List<String> bought = [];
  int restores = 0;

  /// Runs when the store is handed a purchase, before it answers.
  void Function()? onBuy;

  @override
  Future<List<ProPackOffer>> readOffers() async => offers;

  @override
  Future<ProPackStoreResult> buy(ProPackOffer offer) async {
    bought.add(offer.handle);
    onBuy?.call();
    return buyResult;
  }

  @override
  Future<ProPackStoreResult> restore() async {
    restores++;
    return restoreResult;
  }
}

/// Records every event, as if the user had opted in.
class RecordingGate extends NoopTelemetryGate {
  final List<(String, Map<String, Object?>?)> events = [];

  /// Each event as `name {key: value}`, for a plain comparison.
  List<String> get lines => [
    for (final (name, parameters) in events) '$name $parameters',
  ];

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => events.add((name, parameters));
}
