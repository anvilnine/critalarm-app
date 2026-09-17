import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';

/// The three account routes, plus signing out.
abstract interface class AccountRepository {
  /// Sign up and sign in are one call.
  Future<AccountLinkResult> link(String identityToken);

  /// Keep both: this phone's account folds into the identity's.
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  });

  /// Start fresh: the phone joins the identity's account and leaves its own
  /// behind, so the topic tokens on the old one stop working.
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  });

  /// Deletes this device on the server and registers a new one, which leaves
  /// the phone on a fresh anonymous account with a working credential.
  ///
  /// Throws when the delete fails, before anything local is thrown away. A
  /// phone that loses its credential here can never register again.
  Future<void> signOutDevice();

  /// Which mode the server runs in. `selfhosted` has no accounts to sign in
  /// to, so none of the sign-in UI is offered there.
  Future<ServerMode?> readServerMode();
}
