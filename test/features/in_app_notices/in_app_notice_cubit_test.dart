import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_in_app_notice_repository.dart';

class FakeGetConnectionUsecase implements GetConnectionUsecase {
  AppResult<ServerConnection> result = const Failure.notFound(
    message: 'No saved connection',
  ).toFailure();

  @override
  Future<AppResult<ServerConnection>> call(NoParams input) async => result;
}

class FakeIdentityRepo implements IdentityRepository {
  FakeIdentityRepo(this.changes);

  /// The real repository bumps this from its two write points, so the fake
  /// does too.
  final AccountIdentityChanges changes;

  AccountIdentity? identity;

  @override
  bool supports(IdentityProvider provider) => true;

  @override
  Future<IdentitySession> signIn(IdentityProvider provider) async =>
      IdentitySession(
        token: 'token',
        provider: provider,
        email: 'user@test.com',
      );

  @override
  Future<IdentitySession?> readSession() async => null;

  @override
  Future<AccountIdentity?> readIdentity() async => identity;

  @override
  Future<void> saveIdentity(AccountIdentity identity) async {
    this.identity = identity;
    changes.bump();
  }

  @override
  Future<void> clearSession() async {
    identity = null;
    changes.bump();
  }
}

class FakeAccountRepo implements AccountRepository {
  bool holdsHosted = false;
  ServerMode? serverMode = ServerMode.hosted;

  @override
  Future<bool> readHoldsHosted() async => holdsHosted;

  @override
  Future<ServerMode?> readServerMode() async => serverMode;

  @override
  Future<AccountLinkResult> link(
    String identityToken, {
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) async => const AccountLinkResult.claimed(accountId: 'acc1');

  @override
  Future<AccountJoinTokenResult> mintJoinToken() async =>
      const AccountJoinTokenResult.minted(joinToken: 'aj_1');

  @override
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  }) async => const AccountMergeResult.merged(
    accountId: 'acc1',
    mergedFrom: 'acc2',
  );

  @override
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  }) async => const AccountSwitchResult.switched(accountId: 'acc1');

  @override
  Future<void> signOutDevice() async {}

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) async =>
      const AccountDeleteResult.deleted();

  @override
  Future<void> wipeAfterDelete() async {}

  @override
  Future<void> recoverFromDeadCredential() async {}
}

class _FakeProEnding implements ProEnding {
  ProEndingView view = ProEndingView.nothing;
  DateTime? dismissedFor;

  @override
  Future<ProEndingView> read() async => view;

  @override
  Future<void> dismissPill(DateTime endsAt) async => dismissedFor = endsAt;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late FakeInAppNoticeRepository promptRepo;
  late FakeGetConnectionUsecase getConnection;
  late FakeIdentityRepo identityRepo;
  late FakeAccountRepo accountRepo;
  late AccountIdentityChanges identityChanges;
  late _FakeProEnding proEnding;

  // The fake clock. The cubit reads it and the fake repository stamps with it.
  var clockNow = DateTime(2026, 10, 2, 9);
  List<Topic>? topics;

  setUp(() {
    clockNow = DateTime(2026, 10, 2, 9);
    // One plain topic, owned for two days: the backup notice is due.
    topics = [const Topic(name: 'prod-db')];
    promptRepo = FakeInAppNoticeRepository()
      ..now = (() => clockNow)
      ..firstTopicOwnedAt = clockNow.subtract(const Duration(days: 2));
    getConnection = FakeGetConnectionUsecase();
    identityChanges = AccountIdentityChanges();
    identityRepo = FakeIdentityRepo(identityChanges);
    accountRepo = FakeAccountRepo();
    proEnding = _FakeProEnding();
  });

  InAppNoticeCubit buildCubit({
    Duration cooldown = const Duration(seconds: 45),
    Future<bool> Function()? isSetupDone,
  }) {
    return InAppNoticeCubit(
      getConnectionUsecase: getConnection,
      identityRepository: identityRepo,
      accountRepository: accountRepo,
      noticeRepository: promptRepo,
      readTopics: () async => topics,
      clock: () => clockNow,
      proEnding: proEnding,
      cooldownDuration: cooldown,
      identityChanges: identityChanges,
      isSetupDone: isSetupDone,
    );
  }

  group('InAppNoticeCubit Priority & Orchestration', () {
    test('no server saved shows nothing', () async {
      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      await cubit.close();
    });

    test('a dismissal starts the cooldown and it ends by itself', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      proEnding.view = ProEndingView(
        showPill: true,
        endsAt: DateTime(2026, 10, 20),
      );

      // The dismissal itself takes 300 ms, so the cooldown has 200 ms left
      // when it ends.
      final cubit = buildCubit(cooldown: const Duration(milliseconds: 500));
      await cubit.load();
      expect(cubit.state.noticeType, InAppNoticeType.proEnding);

      await cubit.dismissCurrent();
      expect(cubit.state.noticeType, InAppNoticeType.none);
      expect(promptRepo.markResolvedCalls, 1);

      // Still inside the cooldown: a pass shows nothing.
      proEnding.view = ProEndingView.nothing;
      await cubit.load();
      expect(cubit.state.noticeType, InAppNoticeType.none);

      // Wait for the cooldown to end: the backup notice is next.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(cubit.state.noticeType, InAppNoticeType.accountBackup);
      await cubit.close();
    });

    test('onAppResumed resets cooldown immediately', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      proEnding.view = ProEndingView(
        showPill: true,
        endsAt: DateTime(2026, 10, 20),
      );

      final cubit = buildCubit();
      await cubit.load();
      await cubit.dismissCurrent();
      proEnding.view = ProEndingView.nothing;
      await cubit.load();
      expect(cubit.state.noticeType, InAppNoticeType.none);

      // Call onAppResumed -> bypasses remaining 45s cooldown
      await cubit.onAppResumed();
      expect(cubit.state.noticeType, InAppNoticeType.accountBackup);
      await cubit.close();
    });

    test(
      'Priority 4: dismissCurrent snoozes account prompt for 7 days',
      () async {
        getConnection.result = const ServerConnection(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'token123',
        ).toSuccess();

        final cubit = buildCubit(cooldown: const Duration(milliseconds: 50));
        await cubit.load();
        expect(cubit.state.noticeType, InAppNoticeType.accountBackup);

        // Dismiss
        await cubit.dismissCurrent();
        expect(promptRepo.dismissAccountCalls, 1);
        expect(promptRepo.accountDismissedAt, isNotNull);
        expect(cubit.state.noticeType, InAppNoticeType.none);

        // Wait for cooldown to expire
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Account was snoozed and Pro never takes the slot -> all clear
        expect(cubit.state.noticeType, InAppNoticeType.none);
        await cubit.close();
      },
    );

    test(
      'Signing in drops the account prompt with no restart or refresh',
      () async {
        getConnection.result = const ServerConnection(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'token123',
        ).toSuccess();

        final cubit = buildCubit();
        await cubit.load();
        expect(cubit.state.noticeType, InAppNoticeType.accountBackup);

        // Sign in. Nothing else happens: no app restart, no resume, no pull to
        // refresh, no route pop.
        await identityRepo.saveIdentity(
          const AccountIdentity(
            provider: IdentityProvider.google,
            accountId: 'acc_just_signed_in',
            email: 'user@test.com',
          ),
        );
        await pumpEventQueue();

        expect(cubit.state.noticeType, isNot(InAppNoticeType.accountBackup));
        expect(cubit.state.noticeType, InAppNoticeType.none);
        await cubit.close();
      },
    );

    test('Pro never takes the home slot, even unpaid and signed in', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();

      // User already signed in, nothing dismissed, not paying
      identityRepo.identity = const AccountIdentity(
        provider: IdentityProvider.google,
        accountId: 'acc_signed_in',
        email: 'user@test.com',
      );

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      expect(promptRepo.dismissProCalls, 0);
      await cubit.close();
    });

    test('a signed in paid user gets no prompt at all', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();

      // User signed in and paid
      identityRepo.identity = const AccountIdentity(
        provider: IdentityProvider.apple,
        accountId: 'acc_pro',
      );
      accountRepo.holdsHosted = true;

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      await cubit.close();
    });

    test('Self-hosted mode hides Account backup prompt', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://selfhost.critalarm.test',
        adminToken: 'token123',
      ).toSuccess();
      accountRepo.serverMode = ServerMode.selfhosted;

      final cubit = buildCubit();
      await cubit.load();

      // Account backup prompt is skipped and Pro is not a slot prompt
      expect(cubit.state.noticeType, InAppNoticeType.none);
      await cubit.close();
    });
  });

  group('Pro ending pill', () {
    late InAppNoticeCubit cubit;

    setUp(() {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      identityRepo.identity = null;
      accountRepo
        ..serverMode = ServerMode.hosted
        ..holdsHosted = false;
      cubit = buildCubit();
    });

    tearDown(() async {
      await cubit.close();
    });

    test('the Pro ending pill beats the sign-in pill', () async {
      final endsAt = DateTime(2026, 10, 20);
      proEnding.view = ProEndingView(showPill: true, endsAt: endsAt);
      await cubit.load();
      expect(cubit.state.noticeType, InAppNoticeType.proEnding);
      expect(cubit.state.proEndsAt, endsAt);
    });

    test('closing the Pro ending pill tells ProEnding', () async {
      final endsAt = DateTime(2026, 10, 20);
      proEnding.view = ProEndingView(showPill: true, endsAt: endsAt);
      await cubit.load();
      await cubit.dismissCurrent();
      expect(proEnding.dismissedFor, endsAt);
      expect(cubit.state.noticeType, InAppNoticeType.none);
    });

    test('no pill due falls through to the sign-in pill', () async {
      await cubit.load();
      expect(cubit.state.noticeType, InAppNoticeType.accountBackup);
    });
  });

  group('before setup is done', () {
    const connected = ServerConnection(
      serverUrl: 'https://api.critalarm.app',
      adminToken: 'token123',
    );

    test('no server shows nothing during onboarding', () async {
      final cubit = buildCubit(isSetupDone: () async => false);
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      await cubit.close();
    });

    test('no sign-in notice before the Topics guide is seen', () async {
      getConnection.result = connected.toSuccess();
      final cubit = buildCubit(isSetupDone: () async => false);
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      expect(promptRepo.markResolvedCalls, 0);
      await cubit.close();
    });

    test('the sign-in notice shows once setup is done', () async {
      getConnection.result = connected.toSuccess();
      var isDone = false;
      final cubit = buildCubit(isSetupDone: () async => isDone);
      await cubit.load();
      expect(cubit.state.noticeType, InAppNoticeType.none);

      isDone = true;
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.accountBackup);
      await cubit.close();
    });
  });

  group('account backup waits for a topic and a day', () {
    setUp(() {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      promptRepo.firstTopicOwnedAt = null;
    });

    test('no topics means no backup notice and no stamp', () async {
      topics = [];
      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      expect(promptRepo.firstTopicOwnedAt, isNull);
      await cubit.close();
    });

    test('a topic read that failed shows nothing', () async {
      topics = null;
      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      expect(promptRepo.firstTopicOwnedAt, isNull);
      await cubit.close();
    });

    test('a topic created now shows nothing, and is stamped', () async {
      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      expect(promptRepo.firstTopicOwnedAt, clockNow);
      await cubit.close();
    });

    test('23 hours later still nothing', () async {
      final cubit = buildCubit();
      await cubit.load();

      clockNow = clockNow.add(const Duration(hours: 23));
      await cubit.onAppResumed();

      expect(cubit.state.noticeType, InAppNoticeType.none);
      await cubit.close();
    });

    test('25 hours later the notice shows', () async {
      final cubit = buildCubit();
      await cubit.load();

      clockNow = clockNow.add(const Duration(hours: 25));
      await cubit.onAppResumed();

      expect(cubit.state.noticeType, InAppNoticeType.accountBackup);
      await cubit.close();
    });

    test('the stamp is set once, not moved by later passes', () async {
      final cubit = buildCubit();
      await cubit.load();
      final first = promptRepo.firstTopicOwnedAt;

      clockNow = clockNow.add(const Duration(hours: 30));
      await cubit.onAppResumed();

      expect(promptRepo.firstTopicOwnedAt, first);
      await cubit.close();
    });

    test('Pro ending wins over the backup notice', () async {
      promptRepo.firstTopicOwnedAt = clockNow.subtract(const Duration(days: 3));
      proEnding.view = ProEndingView(
        showPill: true,
        endsAt: DateTime(2026, 10, 20),
      );
      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.noticeType, InAppNoticeType.proEnding);
      await cubit.close();
    });
  });
}
