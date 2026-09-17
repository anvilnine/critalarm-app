import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';

final class FakeIdentityRepository implements IdentityRepository {
  int signInCalls = 0;
  int clearCalls = 0;
  AccountIdentity? saved;

  /// Which providers this platform offers. Apple is iOS only in the real
  /// build, so a test can take it away.
  Set<IdentityProvider> available = IdentityProvider.values.toSet();

  @override
  bool supports(IdentityProvider provider) => available.contains(provider);

  @override
  Future<IdentitySession> signIn(IdentityProvider provider) async {
    signInCalls++;
    return IdentitySession(
      token: 'session_$signInCalls',
      provider: provider,
      email: 'someone@example.test',
    );
  }

  @override
  Future<IdentitySession?> readSession() async => null;

  @override
  Future<AccountIdentity?> readIdentity() async => saved;

  @override
  Future<void> saveIdentity(AccountIdentity identity) async => saved = identity;

  @override
  Future<void> clearSession() async {
    clearCalls++;
    saved = null;
  }
}

final class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({required this.linkAnswers});

  /// One answer per call, in order.
  final List<AccountLinkResult> linkAnswers;
  AccountMergeResult mergeAnswer = const AccountMergeResult.merged(
    accountId: 'acc_9',
    mergedFrom: 'acc_1',
  );
  AccountSwitchResult switchAnswer = const AccountSwitchResult.switched(
    accountId: 'acc_9',
  );
  Exception? signOutError;

  final List<String> linkTokens = [];
  int mergeCalls = 0;
  int switchCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AccountLinkResult> link(String identityToken) async {
    linkTokens.add(identityToken);
    return linkAnswers[linkTokens.length - 1];
  }

  @override
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  }) async {
    mergeCalls++;
    return mergeAnswer;
  }

  @override
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  }) async {
    switchCalls++;
    return switchAnswer;
  }

  @override
  Future<void> signOutDevice() async {
    signOutCalls++;
    final error = signOutError;
    if (error != null) throw error;
  }

  ServerMode mode = ServerMode.hosted;

  @override
  Future<ServerMode?> readServerMode() async => mode;
}
