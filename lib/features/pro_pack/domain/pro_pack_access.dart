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
///
/// A kept list belongs to one account on one relay ([ProPackScope]). It is
/// shown only while this phone's account is known and is that one. An
/// unknown account holds nothing, and a different one drops the list.
///
/// Relay answers are applied by one writer. The calls this class makes run
/// one at a time, and an answer is dropped when a newer one is already
/// showing or when it was asked for another account.
final class ProPackAccess {
  ProPackAccess({
    required this._api,
    required this._store,
    required this._readAccountId,
    this._readRelay,
    this._identityChanges = const [],
    ProPackOverride? override,
    this._otherGrant = proPackGrantedElsewhere,
    DateTime Function()? now,
  }) : _override = override ?? appProPackOverride,
       _now = now ?? DateTime.now {
    _last = isHeld;
    _override.listenable?.addListener(_announce);
    for (final changes in _identityChanges) {
      changes.addListener(_identityChanged);
    }
    ready = _syncScope();
  }

  /// api.md §4.2: the relay takes this many refresh calls per account in
  /// [refreshWindow] and answers 429 past it.
  static const refreshLimit = 6;
  static const refreshWindow = Duration(seconds: 60);

  /// How long a kept pack stays held past its `expires_at` when the relay
  /// has not been heard from since. Long enough that someone who renewed
  /// and then had no network is not locked out.
  static const expiredGrace = Duration(days: 3);

  /// How long a purchase the relay has not confirmed is asked about again on
  /// launch and resume before the app stops asking on its own.
  static const pendingConfirmGivesUpAfter = Duration(days: 3);

  final PacksApi _api;
  final ProPackStore _store;
  final Future<String?> Function() _readAccountId;
  final Future<Uri?> Function()? _readRelay;
  final List<Listenable> _identityChanges;
  final ProPackOverride _override;
  final ProPackOtherGrant _otherGrant;
  final DateTime Function() _now;

  final _changes = StreamController<bool>.broadcast();

  /// Done once the kept list has been checked against this phone's account.
  /// Until then nothing is held from the relay.
  late final Future<void> ready;

  /// This phone's account, or null while it is not known.
  ProPackScope? _scope;

  /// The relay's last list for [_scope]. Null for any other account.
  StoredPacks? _kept;

  /// Goes up each time a registration answer names the account, so a slower
  /// read of the stored identity that started before it is thrown away.
  int _scopeEpoch = 0;

  /// The scope of the last registration answer, and the relay the saved
  /// session named when it arrived. A connect registers first and saves its
  /// session a moment later, so until the session moves, the answer's relay
  /// is the one this account is on.
  ProPackScope? _answered;
  String? _sessionRelayAtAnswer;

  /// Requests are numbered as they start. [_applied] is the number of the
  /// answer that is showing.
  int _requests = 0;
  int _applied = 0;
  Future<void> _queue = Future<void>.value();

  ProPackOtherSources _other = const ProPackOtherSources();
  late bool _last;

  DateTime? _lastRead;
  Future<void>? _reading;
  final List<DateTime> _refreshCalls = [];

  /// Whether this install holds the Pro pack, right now.
  bool get isHeld =>
      _relayHolds() || _override.isForcing || _otherGrant(_other);

  /// Every change of [isHeld], and only changes. Read [isHeld] for the
  /// value to start from.
  Stream<bool> get stream => _changes.stream;

  /// The address of a relay as the scope keeps it.
  static String relayText(Uri relay) {
    final text = relay.toString();
    return text.endsWith('/') ? text.substring(0, text.length - 1) : text;
  }

  /// Whether the kept list holds the pack for this account, today.
  ///
  /// A pack with no `expires_at` never ends on the phone. One whose date has
  /// passed stays held for [expiredGrace], counted from that date or from
  /// the relay's last answer if that came later, and seeing the past date
  /// asks the relay again.
  bool _relayHolds() {
    final kept = _kept;
    if (kept == null) return false;
    final now = _now();
    var sawPastDate = false;
    var held = false;
    for (final pack in kept.packs) {
      if (pack.id != proPackId) continue;
      final seconds = pack.expiresAt;
      if (seconds == null) {
        held = true;
        continue;
      }
      final expiry = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      if (!now.isAfter(expiry)) {
        held = true;
        continue;
      }
      sawPastDate = true;
      final answered = kept.answeredAt;
      final from = answered != null && answered.isAfter(expiry)
          ? answered
          : expiry;
      if (now.difference(from) < expiredGrace) held = true;
    }
    if (sawPastDate) unawaited(refresh());
    return held;
  }

  /// Takes the number of a request to the relay that is about to start
  /// somewhere else, such as a registration. Hand it to [relayAnswered].
  int beginRelayRequest() => ++_requests;

  /// A registration response arrived for [accountId]. Its list replaces
  /// whatever was kept, for whatever account.
  ///
  /// [relay] is the relay the registration went to, when the caller named
  /// one. [request] is what [beginRelayRequest] gave before the call: with
  /// it, an answer that comes back after a newer one is dropped.
  Future<void> relayAnswered({
    required String accountId,
    required List<AccountPack> packs,
    String? tier,
    Uri? relay,
    int? request,
  }) async {
    _other = ProPackOtherSources(tier: tier);
    final epoch = ++_scopeEpoch;
    final sessionRelay = await _sessionRelay();
    // A later registration answered while the session was being read.
    if (epoch != _scopeEpoch) return;
    final String? relayOfAnswer;
    if (relay != null) {
      relayOfAnswer = relayText(relay);
    } else {
      relayOfAnswer = _readRelay == null ? '' : sessionRelay;
    }
    if (relayOfAnswer == null) return;
    final scope = ProPackScope(accountId: accountId, relay: relayOfAnswer);
    _answered = scope;
    _sessionRelayAtAnswer = sessionRelay;
    await _useScope(scope);
    await _apply(packs, scope: scope, request: request ?? ++_requests);
  }

  /// Reads `GET /relay/v1/packs`. For launch and resume.
  ///
  /// One read per [refreshWindow] at most, unless [force] is set. A read
  /// that fails changes nothing: the kept answer stands. While a purchase is
  /// still to be confirmed it also asks the relay to read the store again.
  /// Nothing waits on it.
  Future<void> refresh({bool force = false}) {
    final running = _reading;
    if (running != null) return running;
    final last = _lastRead;
    if (!force && last != null) {
      final age = _now().difference(last);
      if (!age.isNegative && age < refreshWindow) return Future<void>.value();
    }
    return _reading = _oneAtATime(_read).whenComplete(() => _reading = null);
  }

  Future<void> _read() async {
    try {
      await _syncScope();
      final scope = _scope;
      // With no account known there is nobody to ask about.
      if (scope == null) return;
      _lastRead = _now();
      final request = ++_requests;
      final answer = await _api.getPacks();
      await _apply(answer.packs, scope: scope, request: request);
      await _confirmPending(scope);
    } on Object catch (error) {
      // No server, no network, a relay that predates the route: all of them
      // leave the kept answer as it is.
      debugPrint('pro_pack_read_failed error=${error.runtimeType}');
    } finally {
      _announce();
    }
  }

  /// Asks the relay to read the store again, after a purchase or a restore,
  /// and applies the table in api.md §4.2.
  ///
  /// [ProPackRefreshOutcome.unknown] keeps what was showing. It is what a
  /// call that could not be made or did not come back answers too, so a
  /// caller only ever has to wait and ask again.
  Future<ProPackRefreshOutcome> confirmWithStore() => _oneAtATime(_confirm);

  Future<ProPackRefreshOutcome> _confirm() async {
    try {
      await _syncScope();
      final scope = _scope;
      if (scope == null) return ProPackRefreshOutcome.unknown;
      final now = _now();
      _refreshCalls.removeWhere((at) {
        final age = now.difference(at);
        return age.isNegative || age >= refreshWindow;
      });
      // Stays one under the relay's limit, so this phone alone never earns
      // a 429. Another phone on the account can still use the budget up.
      if (_refreshCalls.length >= refreshLimit - 1) {
        return ProPackRefreshOutcome.unknown;
      }
      _refreshCalls.add(now);
      final answer = await _api.refreshPacks();
      final outcome = proPackRefreshOutcome(
        confirmed: answer.confirmed,
        listed: listsProPack(answer.packs),
      );
      if (outcome == ProPackRefreshOutcome.unknown) return outcome;
      // The relay read the store inside the call, so this answer is as new
      // as the moment it came back, not the moment it was asked for.
      final applied = await _apply(
        answer.packs,
        scope: scope,
        request: ++_requests,
      );
      return applied ? outcome : ProPackRefreshOutcome.unknown;
    } on Object catch (error) {
      debugPrint('pro_pack_refresh_failed error=${error.runtimeType}');
      return ProPackRefreshOutcome.unknown;
    }
  }

  /// The store is about to be handed a purchase. Remembered on the phone, so
  /// if the app dies before the relay confirms it, the next launch or
  /// resume asks the relay to read the store again ([refresh]).
  Future<void> purchaseStarted() async {
    try {
      await _syncScope();
      final scope = _scope;
      if (scope == null) return;
      await _store.writePending(
        PendingProPackConfirm(scope: scope, since: _now()),
      );
    } on Object catch (error) {
      debugPrint('pro_pack_pending_failed error=${error.runtimeType}');
    }
  }

  /// The person backed out of the store, so there is nothing to confirm.
  Future<void> purchaseAbandoned() async {
    try {
      await _store.clearPending();
    } on Object catch (error) {
      debugPrint('pro_pack_pending_failed error=${error.runtimeType}');
    }
  }

  /// One more ask for a purchase that is still to be confirmed. It stops
  /// once the relay lists the pack, and after [pendingConfirmGivesUpAfter].
  Future<void> _confirmPending(ProPackScope scope) async {
    final pending = _store.readPending();
    if (pending == null) return;
    final age = _now().difference(pending.since);
    if (pending.scope != scope ||
        age.isNegative ||
        age >= pendingConfirmGivesUpAfter ||
        listsProPack(_kept?.packs ?? const [])) {
      await _store.clearPending();
      return;
    }
    await _confirm();
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

  /// Runs the calls this class makes to the relay one after another, so
  /// their answers arrive in the order they were asked for.
  Future<T> _oneAtATime<T>(Future<T> Function() call) {
    final run = _queue.then((_) => call());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  void _identityChanged() => unawaited(_syncScope());

  Future<String?> _sessionRelay() async {
    try {
      final relay = await _readRelay?.call();
      return relay == null ? null : relayText(relay);
    } on Object catch (_) {
      return null;
    }
  }

  /// Reads who this phone is now and drops a kept list that is not theirs.
  Future<void> _syncScope() async {
    final epoch = _scopeEpoch;
    ProPackScope? scope;
    try {
      final accountId = await _readAccountId();
      final sessionRelay = await _sessionRelay();
      final answered = _answered;
      final String? relay;
      if (_readRelay == null) {
        relay = '';
      } else if (answered != null &&
          answered.accountId == accountId &&
          sessionRelay == _sessionRelayAtAnswer) {
        // The session has not moved since the registration answered.
        relay = answered.relay;
      } else {
        relay = sessionRelay;
      }
      if (accountId != null && accountId.isNotEmpty && relay != null) {
        scope = ProPackScope(accountId: accountId, relay: relay);
      }
    } on Object catch (_) {
      scope = null;
    }
    // A registration named the account while this was reading.
    if (epoch != _scopeEpoch) return;
    await _useScope(scope);
  }

  /// Makes [scope] the account this phone answers for. Null is "not known":
  /// nothing is shown and nothing on disk is touched. A known account that
  /// is not the kept one clears the kept list and any purchase waiting.
  Future<void> _useScope(ProPackScope? scope) async {
    _scope = scope;
    if (scope == null) {
      _kept = null;
      _announce();
      return;
    }
    StoredPacks? stored;
    try {
      stored = _store.read();
      if (stored != null && stored.scope != scope) {
        stored = null;
        await _store.clear();
      }
      final pending = _store.readPending();
      if (pending != null && pending.scope != scope) {
        await _store.clearPending();
      }
    } on Object catch (error) {
      debugPrint('pro_pack_store_failed error=${error.runtimeType}');
    }
    // Only replaced from disk when nothing newer for this account is held.
    if (_kept?.scope != scope) _kept = stored;
    _announce();
  }

  /// The one place a relay answer becomes what is showing. False when the
  /// answer was dropped: it was for another account, or a newer one is
  /// already showing.
  Future<bool> _apply(
    List<AccountPack> packs, {
    required ProPackScope scope,
    required int request,
  }) async {
    if (scope != _scope || request < _applied) return false;
    _applied = request;
    final kept = StoredPacks(
      accountId: scope.accountId,
      relay: scope.relay,
      packs: packs,
      answeredAt: _now(),
    );
    _kept = kept;
    _announce();
    try {
      await _store.write(kept);
      if (listsProPack(packs)) await _store.clearPending();
    } on Object catch (error) {
      // The answer still holds for this run of the app.
      debugPrint('pro_pack_store_failed error=${error.runtimeType}');
    }
    return true;
  }

  void _announce() {
    final held = isHeld;
    if (held == _last || _changes.isClosed) return;
    _last = held;
    _changes.add(held);
  }

  Future<void> dispose() async {
    _override.listenable?.removeListener(_announce);
    for (final changes in _identityChanges) {
      changes.removeListener(_identityChanged);
    }
    await _changes.close();
  }
}
