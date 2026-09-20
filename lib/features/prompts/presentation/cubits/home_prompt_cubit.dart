import 'dart:async';

import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Orchestrates home alerts, warnings, and growth prompts following the
/// priority hierarchy, anti-fatigue cooldowns, and 7-day snoozing rules:
/// 1. No server connected (Crit blocker error)
/// 2. Critical health issues (Crit blocker error)
/// 3. Battery optimization off (Warning)
/// 4. Account backup prompt (Engagement, 7-day snooze)
/// 5. Pro support prompt (Monetization, 7-day snooze)
class HomePromptCubit extends Cubit<HomePromptState> {
  HomePromptCubit({
    required this.getConnectionUsecase,
    required this.shellCubit,
    required this.identityRepository,
    required this.accountRepository,
    required this.homePromptRepository,
    ProOverride? proOverride,
    AccountIdentityChanges? identityChanges,
    this.cooldownDuration = const Duration(seconds: 45),
  })  : _proOverride = proOverride ?? appProOverride,
        _identityChanges = identityChanges ?? appAccountIdentityChanges,
        super(const HomePromptState()) {
    _shellSub = shellCubit.stream.listen((health) {
      unawaited(_evaluate(health: health));
    });
    _proOverride.listenable?.addListener(_onForceProChanged);
    _identityChanges.addListener(_onIdentityChanged);
  }

  final GetConnectionUsecase getConnectionUsecase;
  final ShellCubit shellCubit;
  final IdentityRepository identityRepository;
  final AccountRepository accountRepository;
  final HomePromptRepository homePromptRepository;
  final ProOverride _proOverride;
  final AccountIdentityChanges _identityChanges;
  final Duration cooldownDuration;

  StreamSubscription<ShellHealth>? _shellSub;
  Timer? _cooldownTimer;
  DateTime? _lastResolvedOrDismissedAt;

  void _onForceProChanged() {
    if (isClosed) return;
    unawaited(_evaluate());
  }

  /// Somebody signed in, signed out, linked another provider or deleted the
  /// account. Priority 4 reads the identity, so ask again right away instead
  /// of waiting for a resume or a pull to refresh.
  void _onIdentityChanged() {
    if (isClosed) return;
    unawaited(_evaluate());
  }

  Future<void> load() async {
    await _evaluate();
  }

  Future<void> onAppResumed() async {
    _lastResolvedOrDismissedAt = null;
    _cooldownTimer?.cancel();
    await _evaluate(isResumed: true);
  }

  Future<void> refresh() async {
    await shellCubit.refresh();
    await _evaluate();
  }

  Future<void> _evaluate({ShellHealth? health, bool isResumed = false}) async {
    if (isClosed || state.isDismissing) return;

    // Priority 1: Server connection check
    final connResult = await getConnectionUsecase(const NoParams());
    if (isClosed) return;
    final conn = connResult.getOrNull();
    final hasServer = conn != null && conn.serverUrl.trim().isNotEmpty;

    if (!hasServer) {
      emit(
        state.copyWith(
          promptType: HomePromptType.noServer,
          missingPermissions: const [],
        ),
      );
      return;
    }

    // Priority 2 & 3: Device permissions / health
    final currentHealth = health ?? shellCubit.state;
    if (currentHealth.hasCriticalErrors) {
      emit(
        state.copyWith(
          promptType: HomePromptType.criticalHealth,
          missingPermissions: currentHealth.criticalMissing,
        ),
      );
      return;
    }

    if (currentHealth.hasWarningsOnly) {
      emit(
        state.copyWith(
          promptType: HomePromptType.batteryWarning,
          missingPermissions: currentHealth.warningMissing,
        ),
      );
      return;
    }

    // Operational errors/warnings are clear. Check anti-daisy-chaining:
    final wasOperationalIssue =
        state.promptType == HomePromptType.noServer ||
        state.promptType == HomePromptType.criticalHealth ||
        state.promptType == HomePromptType.batteryWarning;

    if (wasOperationalIssue && !isResumed) {
      _lastResolvedOrDismissedAt = DateTime.now();
      await homePromptRepository.markBannerResolvedOrDismissed();
      _startCooldownTimer();
      emit(
        state.copyWith(
          promptType: HomePromptType.none,
          missingPermissions: const [],
        ),
      );
      return;
    }

    // Check active cooldown
    if (!isResumed && _lastResolvedOrDismissedAt != null) {
      final elapsed = DateTime.now().difference(_lastResolvedOrDismissedAt!);
      if (elapsed < cooldownDuration) {
        emit(
          state.copyWith(
            promptType: HomePromptType.none,
            missingPermissions: const [],
          ),
        );
        final remaining = cooldownDuration - elapsed;
        _cooldownTimer?.cancel();
        _cooldownTimer = Timer(remaining, () {
          if (!isClosed) {
            unawaited(_evaluate());
          }
        });
        return;
      }
    }

    // Priority 4: Account Backup Prompt
    final serverMode = await accountRepository.readServerMode();
    final canHaveAccounts = serverMode != ServerMode.selfhosted;
    if (canHaveAccounts) {
      final identity = await identityRepository.readIdentity();
      if (identity == null) {
        final accountDismissedAt =
            homePromptRepository.getAccountPromptDismissedAt();
        final isAccountSnoozed = accountDismissedAt != null &&
            DateTime.now().difference(accountDismissedAt).inDays < 7;
        if (!isAccountSnoozed) {
          emit(
            state.copyWith(
              promptType: HomePromptType.accountBackup,
              missingPermissions: const [],
            ),
          );
          return;
        }
      }
    }

    // Priority 5: Pro Support Prompt
    final isPaid =
        (await accountRepository.readIsPaid()) || _proOverride.isForcingPro;
    if (!isPaid) {
      final proDismissedAt = homePromptRepository.getProPromptDismissedAt();
      final isProSnoozed = proDismissedAt != null &&
          DateTime.now().difference(proDismissedAt).inDays < 7;
      if (!isProSnoozed) {
        emit(
          state.copyWith(
            promptType: HomePromptType.proSupport,
            missingPermissions: const [],
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        promptType: HomePromptType.none,
        missingPermissions: const [],
      ),
    );
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldownDuration, () {
      if (!isClosed) {
        unawaited(_evaluate());
      }
    });
  }

  Future<void> dismissCurrent() async {
    final current = state.promptType;
    if (current == HomePromptType.none || state.isDismissing) return;

    emit(state.copyWith(isDismissing: true));

    if (current == HomePromptType.accountBackup) {
      await homePromptRepository.dismissAccountPrompt();
    } else if (current == HomePromptType.proSupport) {
      await homePromptRepository.dismissProPrompt();
    } else {
      await homePromptRepository.markBannerResolvedOrDismissed();
    }

    _lastResolvedOrDismissedAt = DateTime.now();

    // Smooth exit delay before removing slot content
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!isClosed) {
      emit(
        state.copyWith(
          promptType: HomePromptType.none,
          isDismissing: false,
          missingPermissions: const [],
        ),
      );
      _startCooldownTimer();
    }
  }

  @override
  Future<void> close() {
    unawaited(_shellSub?.cancel());
    _cooldownTimer?.cancel();
    _proOverride.listenable?.removeListener(_onForceProChanged);
    _identityChanges.removeListener(_onIdentityChanged);
    return super.close();
  }
}
