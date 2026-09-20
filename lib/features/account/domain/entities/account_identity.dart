import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter/foundation.dart';

/// Who is signed in on this phone, and which account they landed on.
@immutable
final class AccountIdentity {
  const AccountIdentity({
    required this.provider,
    required this.accountId,
    this.email,
    Set<IdentityProvider>? providers,
  }) : knownProviders = providers;

  /// The way this phone signed in with. It is the one whose email is shown.
  final IdentityProvider provider;

  /// The account the phone belongs to after signing in.
  final String accountId;

  /// Whatever the provider handed back. Apple's private relay address is a
  /// real address, so it is shown exactly as given.
  final String? email;

  /// Every way in the app has watched land on this account, or null on an
  /// account saved before linking existed. Read [providers] instead, which
  /// fills the null in with the one provider this phone signed in with.
  final Set<IdentityProvider>? knownProviders;

  /// Every way in that reaches this account, this phone's own included.
  ///
  /// The contract has no route that lists them, so this is what the app has
  /// watched happen on this handset: the provider it signed in with, plus
  /// each one a link added.
  Set<IdentityProvider> get providers => knownProviders ?? {provider};

  /// Whether [candidate] already reaches this account.
  bool holds(IdentityProvider candidate) => providers.contains(candidate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountIdentity &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          accountId == other.accountId &&
          email == other.email &&
          setEquals(providers, other.providers);

  @override
  int get hashCode => Object.hash(
    provider,
    accountId,
    email,
    Object.hashAllUnordered(providers),
  );
}

/// The person closed the provider sheet without signing in.
///
/// Its own type because backing out is not a failure and must not raise an
/// error banner.
final class IdentitySignInCancelled implements Exception {
  const IdentitySignInCancelled();
}

/// A live session with our own auth surface.
///
/// [token] is the `identity_token` every account route wants. It is issued by
/// our server, not by Apple or Google.
final class IdentitySession {
  const IdentitySession({
    required this.token,
    required this.provider,
    this.email,
  });

  final String token;
  final IdentityProvider provider;
  final String? email;
}
