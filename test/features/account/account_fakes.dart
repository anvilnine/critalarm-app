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

  /// Set to make the next sheet come back cancelled, which is what backing
  /// out of Apple's or Google's dialog looks like.
  bool cancelNextSignIn = false;

  @override
  Future<IdentitySession> signIn(IdentityProvider provider) async {
    if (cancelNextSignIn) {
      cancelNextSignIn = false;
      throw const IdentitySignInCancelled();
    }
    signInCalls++;
    return IdentitySession(
      token: 'session_$signInCalls',
      provider: provider,
      email: 'someone@example.test',
    );
  }

  /// The session from an earlier launch. Null means nobody is signed in,
  /// which is how an anonymous account looks.
  IdentitySession? session;

  @override
  Future<IdentitySession?> readSession() async => session;

  @override
  Future<AccountIdentity?> readIdentity() async => saved;

  @override
  Future<void> saveIdentity(AccountIdentity identity) async => saved = identity;

  @override
  Future<void> clearSession() async {
    clearCalls++;
    saved = null;
    session = null;
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

  /// One answer per delete call, in order. The list running out means the
  /// cubit called more times than the test expected it to.
  List<AccountDeleteResult> deleteAnswers = const [
    AccountDeleteResult.deleted(),
  ];

  /// Thrown instead of answering, which is what offline and a 5xx look like.
  Exception? deleteError;

  /// What was sent in the body each time, nulls included, so a test can see
  /// that an anonymous account sent no identity token at all.
  final List<String?> deleteIdentityTokens = [];
  int wipeCalls = 0;
  int recoverCalls = 0;
  bool isPaid = false;

  final List<String> linkTokens = [];

  /// The intent sent with each link call, in order, so a test can prove the
  /// account screen said `link` and the sign-in screen said `sign_in`.
  final List<AccountLinkIntent> linkIntents = [];

  /// One answer per join-token call, in order.
  List<AccountJoinTokenResult> joinTokenAnswers = const [
    AccountJoinTokenResult.minted(joinToken: 'aj_first'),
  ];

  /// Thrown instead of answering, which is what offline looks like.
  Exception? joinTokenError;

  int joinTokenCalls = 0;
  int mergeCalls = 0;
  int switchCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AccountLinkResult> link(
    String identityToken, {
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) async {
    linkTokens.add(identityToken);
    linkIntents.add(intent);
    return linkAnswers[linkTokens.length - 1];
  }

  @override
  Future<AccountJoinTokenResult> mintJoinToken() async {
    joinTokenCalls++;
    final error = joinTokenError;
    if (error != null) throw error;
    return joinTokenAnswers[joinTokenCalls - 1];
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

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) async {
    deleteIdentityTokens.add(identityToken);
    final error = deleteError;
    if (error != null) throw error;
    return deleteAnswers[deleteIdentityTokens.length - 1];
  }

  @override
  Future<void> wipeAfterDelete() async => wipeCalls++;

  @override
  Future<void> recoverFromDeadCredential() async => recoverCalls++;

  @override
  Future<bool> readIsPaid() async => isPaid;

  ServerMode mode = ServerMode.hosted;

  @override
  Future<ServerMode?> readServerMode() async => mode;
}
