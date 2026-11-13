import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_identities_repository.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/held_session.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';

/// Where the phone stands once [SignInRestore] has looked.
sealed class SignInRestoreOutcome {
  const SignInRestoreOutcome();
}

/// Somebody is signed in: the saved identity, or one just restored.
final class SignInRestoreSignedIn extends SignInRestoreOutcome {
  const SignInRestoreSignedIn(this.identity);

  final AccountIdentity identity;
}

/// Nobody is signed in on this phone, and the account it is on holds at
/// least one identity. [rows] are oldest first and never empty.
final class SignInRestoreUnfinished extends SignInRestoreOutcome {
  const SignInRestoreUnfinished(this.rows);

  final List<AccountIdentityRow> rows;
}

/// Nobody is signed in and the account holds no identity, or the server
/// could not be asked.
final class SignInRestoreSignedOut extends SignInRestoreOutcome {
  const SignInRestoreSignedOut();
}

/// Puts the signed-in state back on a phone that kept its session and lost
/// the record of who it belongs to.
///
/// An iPhone keeps its device credential and its session token in the
/// Keychain across an uninstall, and loses the preferences. After a
/// reinstall the phone is on its old account and rings for it, and read
/// "Not signed in". This asks the server with the session it still holds
/// (`link`, `intent: sign_in`). Only `already_linked` restores, and nothing
/// is shown for it. Every other answer, a 401 or no network leaves the
/// token where it is, and the phone reads which account it is on from the
/// identities list instead.
///
/// It never sends `intent: link`, never merges and never switches. A phone
/// restored from a backup or moved to another one drops its sign-in at
/// launch on purpose ([skipLink]), and this never puts it back.
///
/// One run at a time: the launch, the account screen and the Settings card
/// all ask, and a second ask joins the run in flight.
final class SignInRestore {
  SignInRestore({
    required this.identities,
    required this.account,
    required this.accountIdentities,
    required this.held,
  });

  final IdentityRepository identities;
  final AccountRepository account;
  final AccountIdentitiesRepository accountIdentities;
  final HeldSession held;

  bool _linkSkipped = false;
  Future<SignInRestoreOutcome>? _flight;

  /// The launch found a phone restored from a backup or moved to another one
  /// and dropped its sign-in. No session is sent to the server in this run
  /// of the app.
  void skipLink() => _linkSkipped = true;

  /// True once [skipLink] was called.
  bool get linkSkipped => _linkSkipped;

  Future<SignInRestoreOutcome> run() =>
      _flight ??= _run().whenComplete(() => _flight = null);

  Future<SignInRestoreOutcome> _run() async {
    final saved = await identities.readIdentity();
    if (saved != null) return SignInRestoreSignedIn(saved);
    final mode = await account.readServerMode();
    // No server yet, or a server of the person's own, which has no
    // accounts to sign in to.
    if (mode == null || isOwnServerMode(mode)) {
      return const SignInRestoreSignedOut();
    }

    String? token;
    try {
      token = await held.readOwnToken();
    } on Object catch (_) {
      token = null;
    }

    List<AccountIdentityRow>? rows;
    if (token != null && !_linkSkipped) {
      try {
        final result = await account.link(token);
        if (result case AccountLinkAlreadyLinked(:final accountId)) {
          rows = await accountIdentities.list(identityToken: token);
          final restored = await _restore(rows, accountId);
          if (restored != null) return SignInRestoreSignedIn(restored);
        }
      } on Object catch (_) {
        // Offline, or a server that broke. Falls to the list below.
      }
    }

    try {
      rows ??= await accountIdentities.list(identityToken: token);
    } on Object catch (_) {
      return const SignInRestoreSignedOut();
    }
    if (rows.isEmpty) return const SignInRestoreSignedOut();
    return SignInRestoreUnfinished(rows);
  }

  /// Saves the identity the row marked `current` names. Null when no row is
  /// marked or its provider is one this build does not know, and then
  /// nothing is saved.
  Future<AccountIdentity?> _restore(
    List<AccountIdentityRow> rows,
    String accountId,
  ) async {
    AccountIdentityRow? current;
    for (final row in rows) {
      if (row.current) current = row;
    }
    if (current == null) return null;
    final provider = IdentityProvider.fromWire(current.provider);
    if (provider == null) return null;
    final identity = AccountIdentity(
      provider: provider,
      accountId: accountId,
      email: current.email,
      providers: {
        for (final row in rows) ?IdentityProvider.fromWire(row.provider),
      },
    );
    await identities.saveIdentity(identity);
    return identity;
  }
}
