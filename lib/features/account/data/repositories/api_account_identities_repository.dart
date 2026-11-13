import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/features/account/domain/repositories/account_identities_repository.dart';

/// `GET` and `DELETE /v1/account/identities` on the client every screen talks to.
final class ApiAccountIdentitiesRepository
    implements AccountIdentitiesRepository {
  const ApiAccountIdentitiesRepository({required this.api});

  final ApiClient api;

  @override
  Future<List<AccountIdentityRow>> list({String? identityToken}) =>
      api.listAccountIdentities(identityToken: identityToken);

  @override
  Future<AccountIdentityRemoveResult> remove({
    required String identityId,
    required String identityToken,
  }) => api.removeAccountIdentity(
    identityId: identityId,
    identityToken: identityToken,
  );
}
