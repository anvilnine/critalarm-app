import 'package:critalarm/features/account/domain/entities/account_identity.dart';

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
}
