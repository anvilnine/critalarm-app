import 'package:critalarm/core/api/account_results.dart';

/// The ways to sign in that this phone's account holds (api.md §3.7).
abstract interface class AccountIdentitiesRepository {
  /// Oldest first. Empty for an account that holds no identity.
  ///
  /// [identityToken] is the session this phone holds, if any. Without a good
  /// one the rows carry a masked hint and no address. Throws when the server
  /// cannot be reached or refuses the device token.
  Future<List<AccountIdentityRow>> list({String? identityToken});

  /// Removes the way to sign in [identityId] names, never the last.
  /// [identityToken] is a session of an identity on the account, made no
  /// more than 300 seconds ago. Throws when the server cannot be reached.
  Future<AccountIdentityRemoveResult> remove({
    required String identityId,
    required String identityToken,
  });
}
