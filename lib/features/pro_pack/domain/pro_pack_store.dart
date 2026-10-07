import 'package:critalarm/core/models/account_pack.dart';
import 'package:flutter/foundation.dart';

/// The account a relay answer is about: its id, and the relay that gave it.
///
/// An account id is only a name on the relay that issued it, so the two go
/// together. An answer kept for one scope says nothing about another.
@immutable
final class ProPackScope {
  const ProPackScope({required this.accountId, required this.relay});

  final String accountId;

  /// The relay's address, as text. Empty when the app was built with no way
  /// to name one, which then counts as one relay.
  final String relay;

  @override
  bool operator ==(Object other) =>
      other is ProPackScope &&
      other.accountId == accountId &&
      other.relay == relay;

  @override
  int get hashCode => Object.hash(accountId, relay);

  @override
  String toString() => 'ProPackScope($accountId, $relay)';
}

/// The packs the relay last listed, who it listed them for, and when.
@immutable
final class StoredPacks {
  const StoredPacks({
    required this.packs,
    this.accountId,
    this.relay = '',
    this.answeredAt,
  });

  final String? accountId;
  final String relay;
  final List<AccountPack> packs;

  /// When the relay gave this answer, by the phone's clock.
  final DateTime? answeredAt;

  /// Null for a value kept before the account was known. Such a value is
  /// never shown.
  ProPackScope? get scope => accountId == null
      ? null
      : ProPackScope(accountId: accountId!, relay: relay);
}

/// A purchase the store took and the relay has not confirmed yet.
@immutable
final class PendingProPackConfirm {
  const PendingProPackConfirm({required this.scope, required this.since});

  final ProPackScope scope;

  /// When the purchase was started, by the phone's clock.
  final DateTime since;
}

/// Keeps the relay's last answer on the phone, so a cold start with no
/// network still knows it, and a purchase that is still to be confirmed.
abstract interface class ProPackStore {
  /// Null when the relay has never answered on this phone.
  StoredPacks? read();

  Future<void> write(StoredPacks packs);

  Future<void> clear();

  PendingProPackConfirm? readPending();

  Future<void> writePending(PendingProPackConfirm pending);

  Future<void> clearPending();
}
