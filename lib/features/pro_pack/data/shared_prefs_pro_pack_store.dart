import 'dart:convert';

import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ProPackStore] in the app's preferences, as one JSON value.
final class SharedPrefsProPackStore implements ProPackStore {
  const SharedPrefsProPackStore(this._prefs);

  static const key = 'pro_pack.relay_packs';

  final SharedPreferences _prefs;

  @override
  StoredPacks? read() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final account = json['account_id'];
      return StoredPacks(
        accountId: account is String ? account : null,
        packs: accountPacksFromJson(json['packs']),
      );
    } on FormatException {
      // A value that does not read back is the same as none.
      return null;
    }
  }

  @override
  Future<void> write(StoredPacks packs) => _prefs.setString(
    key,
    jsonEncode({
      'account_id': packs.accountId,
      'packs': accountPacksToJson(packs.packs),
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);
}
