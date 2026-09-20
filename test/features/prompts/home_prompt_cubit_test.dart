import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHomePromptRepository implements HomePromptRepository {
  DateTime? accountDismissedAt;
  DateTime? proDismissedAt;
  DateTime? lastResolvedAt;

  int dismissAccountCalls = 0;
  int dismissProCalls = 0;
  int markResolvedCalls = 0;

  @override
  DateTime? getAccountPromptDismissedAt() => accountDismissedAt;

  @override
  Future<void> dismissAccountPrompt() async {
    dismissAccountCalls++;
    accountDismissedAt = DateTime.now();
    await markBannerResolvedOrDismissed();
  }

  @override
  DateTime? getProPromptDismissedAt() => proDismissedAt;

  @override
  Future<void> dismissProPrompt() async {
    dismissProCalls++;
    proDismissedAt = DateTime.now();
    await markBannerResolvedOrDismissed();
  }

  @override
  DateTime? getLastBannerResolvedOrDismissedAt() => lastResolvedAt;

  @override
  Future<void> markBannerResolvedOrDismissed() async {
    markResolvedCalls++;
    lastResolvedAt = DateTime.now();
  }
}

class FakeGetConnectionUsecase implements GetConnectionUsecase {
  AppResult<ServerConnection> result = const Failure.notFound(
    message: 'No saved connection',
  ).toFailure();

  @override
  Future<AppResult<ServerConnection>> call(NoParams input) async => result;
}

class FakeShellCubit extends ShellCubit {
  FakeShellCubit() : super(FakeGetDevicePermissionsUsecase());

  void setHealth(ShellHealth health) {
    emit(health);
  }
}

class FakeGetDevicePermissionsUsecase implements GetDevicePermissionsUsecase {
  @override
  Future<AppResult<List<DevicePermissionItem>>> call(NoParams input) async =>
      const Success([]);
}

class FakeIdentityRepo implements IdentityRepository {
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
  Future<void> saveIdentity(AccountIdentity identity) async =>
      this.identity = identity;

  @override
  Future<void> clearSession() async => identity = null;
}

class FakeAccountRepo implements AccountRepository {
  bool isPaid = false;
  ServerMode? serverMode = ServerMode.hosted;

  @override
  Future<bool> readIsPaid() async => isPaid;

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
  }) async =>
      const AccountMergeResult.merged(
        accountId: 'acc1',
        mergedFrom: 'acc2',
      );

  @override
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  }) async =>
      const AccountSwitchResult.switched(accountId: 'acc1');

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

void main() {
  late FakeHomePromptRepository promptRepo;
  late FakeGetConnectionUsecase getConnection;
  late FakeShellCubit shellCubit;
  late FakeIdentityRepo identityRepo;
  late FakeAccountRepo accountRepo;

  setUp(() {
    promptRepo = FakeHomePromptRepository();
    getConnection = FakeGetConnectionUsecase();
    shellCubit = FakeShellCubit();
    identityRepo = FakeIdentityRepo();
    accountRepo = FakeAccountRepo();
  });

  HomePromptCubit buildCubit({
    Duration cooldown = const Duration(seconds: 45),
    ProOverride? proOverride,
  }) {
    return HomePromptCubit(
      getConnectionUsecase: getConnection,
      shellCubit: shellCubit,
      identityRepository: identityRepo,
      accountRepository: accountRepo,
      homePromptRepository: promptRepo,
      cooldownDuration: cooldown,
      proOverride: proOverride ?? const NoProOverride(),
    );
  }

  group('HomePromptCubit Priority & Orchestration', () {
    test('Priority 1: emits noServer when no connection saved', () async {
      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.promptType, HomePromptType.noServer);
      await cubit.close();
    });

    test('Priority 2: emits criticalHealth when notifications missing',
        () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();

      shellCubit.setHealth(
        const ShellHealth(
          missing: [
            DevicePermissionItem(
              type: DevicePermissionType.notifications,
              status: DevicePermissionStatus.denied,
              title: 'Notifications',
              description: 'Required for alerts',
              canFix: true,
            ),
          ],
        ),
      );

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.promptType, HomePromptType.criticalHealth);
      expect(cubit.state.missingPermissions.length, 1);
      await cubit.close();
    });

    test('Priority 3: emits batteryWarning when only battery opt is missing',
        () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();

      shellCubit.setHealth(
        const ShellHealth(
          missing: [
            DevicePermissionItem(
              type: DevicePermissionType.batteryOptimization,
              status: DevicePermissionStatus.denied,
              title: 'Battery optimization',
              description: 'May delay alerts',
              canFix: true,
            ),
          ],
        ),
      );

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.promptType, HomePromptType.batteryWarning);
      expect(cubit.state.missingPermissions.length, 1);
      await cubit.close();
    });

    test('Cadence: operational issue resolution triggers cooldown', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();

      // Start with battery warning
      shellCubit.setHealth(
        const ShellHealth(
          missing: [
            DevicePermissionItem(
              type: DevicePermissionType.batteryOptimization,
              status: DevicePermissionStatus.denied,
              title: 'Battery optimization',
              description: 'May delay alerts',
              canFix: true,
            ),
          ],
        ),
      );

      final cubit = buildCubit(cooldown: const Duration(milliseconds: 50));
      await cubit.load();
      expect(cubit.state.promptType, HomePromptType.batteryWarning);

      // Now resolve battery warning
      shellCubit.setHealth(const ShellHealth());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should be in cooldown (none) and mark banner resolved
      expect(cubit.state.promptType, HomePromptType.none);
      expect(promptRepo.markResolvedCalls, 1);

      // Wait for cooldown to expire (50ms)
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Now Account prompt should appear (signed out)
      expect(cubit.state.promptType, HomePromptType.accountBackup);
      await cubit.close();
    });

    test('onAppResumed resets cooldown immediately', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();

      shellCubit.setHealth(
        const ShellHealth(
          missing: [
            DevicePermissionItem(
              type: DevicePermissionType.batteryOptimization,
              status: DevicePermissionStatus.denied,
              title: 'Battery optimization',
              description: 'May delay alerts',
              canFix: true,
            ),
          ],
        ),
      );

      final cubit = buildCubit();
      await cubit.load();

      // Clear health issue
      shellCubit.setHealth(const ShellHealth());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.promptType, HomePromptType.none);

      // Call onAppResumed -> bypasses remaining 45s cooldown
      await cubit.onAppResumed();
      expect(cubit.state.promptType, HomePromptType.accountBackup);
      await cubit.close();
    });

    test('Priority 4: dismissCurrent snoozes account prompt for 7 days',
        () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      shellCubit.setHealth(const ShellHealth());

      final cubit = buildCubit(cooldown: const Duration(milliseconds: 50));
      await cubit.load();
      expect(cubit.state.promptType, HomePromptType.accountBackup);

      // Dismiss
      await cubit.dismissCurrent();
      expect(promptRepo.dismissAccountCalls, 1);
      expect(promptRepo.accountDismissedAt, isNotNull);
      expect(cubit.state.promptType, HomePromptType.none);

      // Wait for cooldown to expire
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Account was snoozed -> falls through to Priority 5 (Pro support)
      expect(cubit.state.promptType, HomePromptType.proSupport);
      await cubit.close();
    });

    test('Priority 5: dismissCurrent snoozes Pro prompt for 7 days', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      shellCubit.setHealth(const ShellHealth());

      // User already signed in
      identityRepo.identity = const AccountIdentity(
        provider: IdentityProvider.google,
        accountId: 'acc_signed_in',
        email: 'user@test.com',
      );

      final cubit = buildCubit(cooldown: const Duration(milliseconds: 50));
      await cubit.load();
      expect(cubit.state.promptType, HomePromptType.proSupport);

      // Dismiss Pro prompt
      await cubit.dismissCurrent();
      expect(promptRepo.dismissProCalls, 1);
      expect(promptRepo.proDismissedAt, isNotNull);
      expect(cubit.state.promptType, HomePromptType.none);

      // Wait for cooldown to expire
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Both snoozed / signed in -> all clear (none)
      expect(cubit.state.promptType, HomePromptType.none);
      await cubit.close();
    });

    test('Paid or ProOverride hides Pro support prompt', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'token123',
      ).toSuccess();
      shellCubit.setHealth(const ShellHealth());

      // User signed in and paid
      identityRepo.identity = const AccountIdentity(
        provider: IdentityProvider.apple,
        accountId: 'acc_pro',
      );
      accountRepo.isPaid = true;

      final cubit = buildCubit();
      await cubit.load();

      expect(cubit.state.promptType, HomePromptType.none);
      await cubit.close();
    });

    test('Self-hosted mode hides Account backup prompt', () async {
      getConnection.result = const ServerConnection(
        serverUrl: 'https://selfhost.critalarm.test',
        adminToken: 'token123',
      ).toSuccess();
      shellCubit.setHealth(const ShellHealth());
      accountRepo.serverMode = ServerMode.selfhosted;

      final cubit = buildCubit();
      await cubit.load();

      // Account backup prompt is skipped, shows Pro prompt directly
      expect(cubit.state.promptType, HomePromptType.proSupport);
      await cubit.close();
    });
  });
}
