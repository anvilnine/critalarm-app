import 'package:critalarm/core/models/account_pack.dart';
import 'package:flutter/foundation.dart';

/// The packs the relay last listed, and the account it listed them for.
@immutable
final class StoredPacks {
  const StoredPacks({required this.packs, this.accountId});

  final String? accountId;
  final List<AccountPack> packs;
}

/// Keeps the relay's last answer on the phone, so a cold start with no
/// network still knows it.
abstract interface class ProPackStore {
  /// Null when the relay has never answered on this phone.
  StoredPacks? read();

  Future<void> write(StoredPacks packs);

  Future<void> clear();
}
