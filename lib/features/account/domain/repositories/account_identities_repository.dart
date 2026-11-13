import 'package:critalarm/core/api/account_results.dart';

/// The ways to sign in that this phone's account holds (api.md §3.7).
// ignore: one_member_abstracts
abstract interface class AccountIdentitiesRepository {
  /// Oldest first. Empty for an account that holds no identity.
  ///
  /// [identityToken] is the session this phone holds, if any. Without a good
  /// one the rows carry a masked hint and no address. Throws when the server
  /// cannot be reached or refuses the device token.
  Future<List<AccountIdentityRow>> list({String? identityToken});
}
