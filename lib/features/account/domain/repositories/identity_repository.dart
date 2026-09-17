import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';

/// Getting and keeping an identity token.
///
/// Two steps hide behind [signIn]: the provider's own sheet, then an exchange
/// with our server for a session of our own. What Apple and Google hand back
/// is not what the account routes accept.
abstract interface class IdentityRepository {
  /// True when this build can offer [provider] on this platform.
  bool supports(IdentityProvider provider);

  /// Runs the provider sheet and exchanges the result for a session.
  Future<IdentitySession> signIn(IdentityProvider provider);

  /// The session from an earlier launch, so a signed-in person is not asked
  /// to sign in again on every start.
  Future<IdentitySession?> readSession();

  /// Who the account screen shows, or null when nobody is signed in.
  Future<AccountIdentity?> readIdentity();

  Future<void> saveIdentity(AccountIdentity identity);

  /// Drops the stored session and signs out of the provider.
  Future<void> clearSession();
}
