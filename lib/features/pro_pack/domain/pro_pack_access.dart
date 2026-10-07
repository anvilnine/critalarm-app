import 'dart:async';

import 'package:critalarm/core/api/packs_api.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_grant.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:flutter/foundation.dart';

/// Answers one question: does this install hold the Pro pack.
///
/// It never says how the pack was granted. Three things feed it:
///
/// - The relay's `packs` list (api.md §4.2): every registration response,
///   `GET /relay/v1/packs` on launch and resume, and
///   `POST /relay/v1/packs/refresh` after a purchase or a restore. The last
///   list is kept on the phone, so a cold start with no network still
///   answers.
/// - The developer switch, in a build compiled with one ([ProPackOverride]).
/// - [ProPackOtherGrant], the one function that could grant the pack from
///   another source. It grants nothing today.
///
/// The tier is not one of them. A pack is never worked out from a tier.
final class ProPackAccess {
  ProPackAccess({
    required this._api,
    required this._store,
    required this._readAccountId,
    ProPackOverride? override,
    this._otherGrant = proPackGrantedElsewhere,
    DateTime Function()? now,
  }) : _override = override ?? appProPackOverride,
       _now = now ?? DateTime.now {
    _listed = listsProPack(_store.read()?.packs ?? const []);
    _last = isHeld;
    _override.listenable?.addListener(_announce);
  }

  /// api.md §4.2: the relay takes this many refresh calls per account in
  /// [refreshWindow] and answers 429 past it.
  static const refreshLimit = 6;
  static const refreshWindow = Duration(seconds: 60);

  final PacksApi _api;
  final ProPackStore _store;
  final Future<String?> Function() _readAccountId;
  final ProPackOverride _override;
  final ProPackOtherGrant _otherGrant;
  final DateTime Function() _now;

  final _changes = StreamController<bool>.broadcast();

  /// Whether the relay's last list held the pack.
  bool _listed = false;
  ProPackOtherSources _other = const ProPackOtherSources();
  late bool _last;

  DateTime? _lastRead;
  Future<void>? _reading;
  final List<DateTime> _refreshCalls = [];

  /// Whether this install holds the Pro pack, right now.
  bool get isHeld => _listed || _override.isForcing || _otherGrant(_other);

  /// Every change of [isHeld], and only changes. Read [isHeld] for the
  /// value to start from.
  Stream<bool> get stream => _changes.stream;

  /// A registration response arrived for [accountId]. Its list replaces
  /// whatever was kept, for whatever account.
  Future<void> relayAnswered({
    required String accountId,
    required List<AccountPack> packs,
    String? tier,
  }) async {
    _other = ProPackOtherSources(tier: tier);
    await _keep(packs, accountId: accountId);
  }

  /// Reads `GET /relay/v1/packs`. For launch and resume.
  ///
  /// One read per [refreshWindow] at most, unless [force] is set. A read
  /// that fails changes nothing: the kept answer stands.
  Future<void> refresh({bool force = false}) {
    final running = _reading;
    if (running != null) return running;
    final last = _lastRead;
    if (!force && last != null) {
      final age = _now().difference(last);
      if (!age.isNegative && age < refreshWindow) return Future<void>.value();
    }
    return _reading = _read().whenComplete(() => _reading = null);
  }

  Future<void> _read() async {
    try {
      final accountId = await _dropOtherAccount();
      _lastRead = _now();
      final answer = await _api.getPacks();
      await _keep(answer.packs, accountId: accountId);
    } on Object catch (error) {
      // No server, no network, a relay that predates the route: all of them
      // leave the kept answer as it is.
      debugPrint('pro_pack_read_failed error=${error.runtimeType}');
    }
  }

  /// Asks the relay to read the store again, after a purchase or a restore,
  /// and applies the table in api.md §4.2.
  ///
  /// [ProPackRefreshOutcome.unknown] keeps what was showing. It is what a
  /// call that could not be made or did not come back answers too, so a
  /// caller only ever has to wait and ask again.
  Future<ProPackRefreshOutcome> confirmWithStore() async {
    final now = _now();
    _refreshCalls.removeWhere((at) {
      final age = now.difference(at);
      return age.isNegative || age >= refreshWindow;
    });
    // Stays one under the relay's limit, so this phone alone never earns a
    // 429. Another phone on the account can still use the budget up.
    if (_refreshCalls.length >= refreshLimit - 1) {
      return ProPackRefreshOutcome.unknown;
    }
    _refreshCalls.add(now);
    try {
      final accountId = await _dropOtherAccount();
      final answer = await _api.refreshPacks();
      final outcome = proPackRefreshOutcome(
        confirmed: answer.confirmed,
        listed: listsProPack(answer.packs),
      );
      if (outcome != ProPackRefreshOutcome.unknown) {
        await _keep(answer.packs, accountId: accountId);
      }
      return outcome;
    } on Object catch (error) {
      debugPrint('pro_pack_refresh_failed error=${error.runtimeType}');
      return ProPackRefreshOutcome.unknown;
    }
  }

  /// A route answered `403 {"error":"pack","pack":...}`: it needs a pack the
  /// relay says this account does not hold.
  ///
  /// The app does not take the pack away on its own. It reads the relay's
  /// list again, at once, and shows what that says. An id other than the
  /// Pro pack is passed over.
  Future<void> relayRefused(String? packId) async {
    if (packId != proPackId) return;
    await refresh(force: true);
  }

  /// The kept list belongs to one account. After a sign-out or a move to
  /// another account it says nothing about this one, so it is dropped.
  Future<String?> _dropOtherAccount() async {
    final accountId = await _readAccountId();
    final kept = _store.read();
    if (kept != null &&
        kept.accountId != null &&
        accountId != null &&
        kept.accountId != accountId) {
      _listed = false;
      await _store.clear();
      _announce();
    }
    return accountId;
  }

  Future<void> _keep(List<AccountPack> packs, {String? accountId}) async {
    _listed = listsProPack(packs);
    _announce();
    try {
      await _store.write(StoredPacks(accountId: accountId, packs: packs));
    } on Object catch (error) {
      // The answer still holds for this run of the app.
      debugPrint('pro_pack_store_failed error=${error.runtimeType}');
    }
  }

  void _announce() {
    final held = isHeld;
    if (held == _last || _changes.isClosed) return;
    _last = held;
    _changes.add(held);
  }

  Future<void> dispose() async {
    _override.listenable?.removeListener(_announce);
    await _changes.close();
  }
}
