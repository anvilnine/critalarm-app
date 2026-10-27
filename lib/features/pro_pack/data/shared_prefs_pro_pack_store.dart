import 'dart:convert';

import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ProPackStore] in the app's preferences, one JSON value per key.
final class SharedPrefsProPackStore implements ProPackStore {
  const SharedPrefsProPackStore(this._prefs);

  static const key = 'pro_pack.relay_packs';
  static const pendingKey = 'pro_pack.pending_confirm';

  final SharedPreferences _prefs;

  /// A value that does not read back is the same as none.
  Map<Object?, Object?>? _map(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map ? json : null;
    } on FormatException {
      return null;
    }
  }

  static DateTime? _time(Object? seconds) => seconds is num
      ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
      : null;

  static int _seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

  @override
  StoredPacks? read() {
    final json = _map(key);
    if (json == null) return null;
    final account = json['account_id'];
    final relay = json['relay'];
    return StoredPacks(
      accountId: account is String ? account : null,
      relay: relay is String ? relay : '',
      packs: accountPacksFromJson(json['packs']),
      answeredAt: _time(json['answered_at']),
    );
  }

  @override
  Future<void> write(StoredPacks packs) => _prefs.setString(
    key,
    jsonEncode({
      'account_id': packs.accountId,
      'relay': packs.relay,
      'packs': accountPacksToJson(packs.packs),
      'answered_at': packs.answeredAt == null
          ? null
          : _seconds(packs.answeredAt!),
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);

  @override
  PendingProPackConfirm? readPending() {
    final json = _map(pendingKey);
    if (json == null) return null;
    final account = json['account_id'];
    final relay = json['relay'];
    final since = _time(json['since']);
    if (account is! String || relay is! String || since == null) return null;
    return PendingProPackConfirm(
      scope: ProPackScope(accountId: account, relay: relay),
      since: since,
      // Anything but a written true is a purchase that was only started.
      storeAccepted: json['store_accepted'] == true,
    );
  }

  @override
  Future<void> writePending(PendingProPackConfirm pending) => _prefs.setString(
    pendingKey,
    jsonEncode({
      'account_id': pending.scope.accountId,
      'relay': pending.scope.relay,
      'since': _seconds(pending.since),
      if (pending.storeAccepted) 'store_accepted': true,
    }),
  );

  @override
  Future<void> clearPending() => _prefs.remove(pendingKey);
}
