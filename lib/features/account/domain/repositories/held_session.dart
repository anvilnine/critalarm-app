import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter/foundation.dart';

/// The session token this phone holds, read and written on its own.
///
/// An iPhone keeps the token in the Keychain across an uninstall and loses
/// the preferences that say who it belongs to, so the token has to be
/// readable without them.
abstract interface class HeldSession {
  /// The token this phone holds of its own, or null. Never one that came in
  /// a backup: a copy in the preferences is dropped, never moved in. Null
  /// when the store cannot answer.
  Future<String?> readOwnToken();

  /// Writes [session] back as the one this phone holds. Signing out drops
  /// the stored session, so leaving one account to sign in to another puts
  /// the new one back with this.
  Future<void> keep(IdentitySession session);

  /// What is held right now: the token and the provider and email stored
  /// beside it, each of them possibly missing.
  Future<HeldSnapshot> snapshot();

  /// Writes [snapshot] back exactly, removing what it does not hold. A
  /// provider sign-in writes its session over the held one before the server
  /// has said the identity is on this account, so a sign-in that does not
  /// finish puts back what was there.
  Future<void> putBack(HeldSnapshot snapshot);
}

/// The held session as it was at one moment. After a reinstall an iPhone can
/// hold a token with no provider beside it, so each part stands alone.
@immutable
final class HeldSnapshot {
  const HeldSnapshot({this.token, this.provider, this.email});

  final String? token;
  final IdentityProvider? provider;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is HeldSnapshot &&
      other.token == token &&
      other.provider == provider &&
      other.email == email;

  @override
  int get hashCode => Object.hash(token, provider, email);
}
