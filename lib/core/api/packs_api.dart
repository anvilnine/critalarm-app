import 'package:critalarm/core/models/account_pack.dart';

/// The two relay routes that answer for an account's packs (api.md §4.2).
///
/// Both are authorised with this device's own `dv_` token.
abstract interface class PacksApi {
  /// GET /relay/v1/packs
  ///
  /// Answers from what the relay holds. It never calls the store.
  Future<PacksAnswer> getPacks();

  /// POST /relay/v1/packs/refresh
  ///
  /// Asks the relay to read the store again. For after a purchase or a
  /// restore, so nobody waits on a webhook. The relay limits it per account
  /// and answers 429 over the limit.
  Future<PacksRefreshAnswer> refreshPacks();
}

/// For a build whose API client does not speak the pack routes. Every call
/// fails the same way a missing server does, so a caller keeps what it had.
final class NoPacksApi implements PacksApi {
  const NoPacksApi();

  @override
  Future<PacksAnswer> getPacks() => throw StateError('No packs API');

  @override
  Future<PacksRefreshAnswer> refreshPacks() => throw StateError('No packs API');
}
