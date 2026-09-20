import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';

/// The account routes, plus signing out and starting over.
abstract interface class AccountRepository {
  /// Sign up and sign in are one call.
  ///
  /// [intent] says which screen the person was on. The sign-in screen sends
  /// `sign_in`; the account screen, under the button that adds another way in,
  /// sends `link` (api.md §3.7).
  Future<AccountLinkResult> link(
    String identityToken, {
    AccountLinkIntent intent,
  });

  /// Mints a fresh join code for this account and hands it back once. The
  /// code before it stops working, and nothing can read the new one back.
  Future<AccountJoinTokenResult> mintJoinToken();

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

  /// Erases the account on the server. Touches nothing on the phone, whatever
  /// the answer is.
  ///
  /// [identityToken] is left out when nobody is signed in, because an account
  /// with no identity is deleted on the device token alone.
  Future<AccountDeleteResult> deleteAccount({String? identityToken});

  /// Throws away everything the deleted account left on the phone and
  /// registers again, which lands on a fresh anonymous account.
  ///
  /// Only ever called after a 204. Running it on a call that failed leaves a
  /// live account nobody can reach and a phone that has forgotten it.
  Future<void> wipeAfterDelete();

  /// Recovers from a device token the server no longer knows.
  ///
  /// Somebody deleted the account from another handset, so this one is
  /// holding a credential that will answer 401 for ever. Stops any alarm
  /// still ringing, clears the same state a delete clears, and registers
  /// fresh. Safe to call more than once: a recovery already running wins and
  /// the later calls do nothing.
  Future<void> recoverFromDeadCredential();

  /// Whether this device is registered on a paid tier.
  ///
  /// The delete prompt has to say that a store subscription keeps billing
  /// after the account is gone, and only somebody paying needs to read it.
  Future<bool> readIsPaid();

  /// Which mode the server runs in. `selfhosted` has no accounts to sign in
  /// to, so none of the sign-in UI is offered there.
  Future<ServerMode?> readServerMode();
}
