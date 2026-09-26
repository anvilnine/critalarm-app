import 'dart:async';

import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Runs home alerts, warnings, and growth notices following the priority
/// hierarchy, anti-fatigue cooldowns, and 7-day snoozing rules:
/// 1. No server connected (Crit blocker error)
/// 2. Critical health issues (Crit blocker error)
/// 3. Battery optimization off (Warning)
/// 4. Pro ends soon (cancelled plan, 5-day snooze)
/// 5. Account backup prompt (Engagement, 7-day snooze)
///
/// Nothing shows before setup is done (`SetupGate`): onboarding finished,
/// including the create-your-first-topic screens, and the Topics Feature
/// Guide seen or skipped. Home loads again when a guide ends.
///
/// Pro is not on this list. It is a sheet now, asked for by `ProAskRules`
/// in `lib/features/in_app_notices/domain/pro_ask_rules.dart` at a moment that
/// earns the ask, never a card sitting on the home screen.
class InAppNoticeCubit extends Cubit<InAppNoticeState> {
  InAppNoticeCubit({
    required this.getConnectionUsecase,
    required this.shellCubit,
    required this.identityRepository,
    required this.accountRepository,
    required this.noticeRepository,
    this.proEnding,
    AccountIdentityChanges? identityChanges,
    Future<bool> Function()? isSetupDone,
    this.cooldownDuration = const Duration(seconds: 45),
  }) : _identityChanges = identityChanges ?? appAccountIdentityChanges,
       // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone,
       super(const InAppNoticeState()) {
    _shellSub = shellCubit.stream.listen((health) {
      unawaited(_evaluate(health: health));
    });
    _identityChanges.addListener(_onIdentityChanged);
  }

  final GetConnectionUsecase getConnectionUsecase;
  final ShellCubit shellCubit;
  final IdentityRepository identityRepository;
  final AccountRepository accountRepository;
  final InAppNoticeRepository noticeRepository;
  final ProEnding? proEnding;
  final AccountIdentityChanges _identityChanges;
  final Duration cooldownDuration;

  /// `SetupGate.isDone` in the app. Null in tests that do not care, and
  /// counts as done.
  final Future<bool> Function()? _isSetupDone;

  StreamSubscription<ShellHealth>? _shellSub;
  Timer? _cooldownTimer;
  DateTime? _lastResolvedOrDismissedAt;

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

    // Nothing before setup is done: not during onboarding, and not before
    // the Topics guide has been seen. The state is left as it is rather than
    // set to none: before the Topics guide it is still the first none, and
    // while a later guide is up Home hides the notice itself. Keeping it
    // lets the pass after the guide see a cleared blocker and start the
    // cooldown.
    final isSetupDone =
        await (_isSetupDone?.call() ?? Future<bool>.value(true));
    if (isClosed || !isSetupDone) return;

    // Priority 1: Server connection check
    final connResult = await getConnectionUsecase(const NoParams());
    if (isClosed) return;
    final conn = connResult.getOrNull();
    final hasServer = conn != null && conn.serverUrl.trim().isNotEmpty;

    if (!hasServer) {
      emit(
        state.copyWith(
          noticeType: InAppNoticeType.noServer,
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
          noticeType: InAppNoticeType.criticalHealth,
          missingPermissions: currentHealth.criticalMissing,
        ),
      );
      return;
    }

    // Battery optimisation never shows a notice here. It is a warning, not a
    // blocker, and the home screen asking about it on every launch reads as
    // nagging. It stays on the Settings health row, where the user goes to
    // look.

    // Operational errors are clear. Check anti-daisy-chaining:
    final wasOperationalIssue =
        state.noticeType == InAppNoticeType.noServer ||
        state.noticeType == InAppNoticeType.criticalHealth;

    if (wasOperationalIssue && !isResumed) {
      _lastResolvedOrDismissedAt = DateTime.now();
      await noticeRepository.markNoticeResolvedOrDismissed();
      _startCooldownTimer();
      emit(
        state.copyWith(
          noticeType: InAppNoticeType.none,
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
            noticeType: InAppNoticeType.none,
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

    // Priority 4: a cancelled Pro plan that has not ended yet.
    final ending = await proEnding?.read();
    if (isClosed) return;
    if (ending != null && ending.showPill) {
      emit(
        state.copyWith(
          noticeType: InAppNoticeType.proEnding,
          proEndsAt: ending.endsAt,
          missingPermissions: const [],
        ),
      );
      return;
    }

    // Priority 5: Account Backup Notice
    final serverMode = await accountRepository.readServerMode();
    final canHaveAccounts = serverMode != ServerMode.selfhosted;
    if (canHaveAccounts) {
      final identity = await identityRepository.readIdentity();
      if (identity == null) {
        final accountDismissedAt = noticeRepository
            .getAccountNoticeDismissedAt();
        final isAccountSnoozed =
            accountDismissedAt != null &&
            DateTime.now().difference(accountDismissedAt).inDays < 7;
        if (!isAccountSnoozed) {
          emit(
            state.copyWith(
              noticeType: InAppNoticeType.accountBackup,
              missingPermissions: const [],
            ),
          );
          return;
        }
      }
    }

    emit(
      state.copyWith(
        noticeType: InAppNoticeType.none,
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
    final current = state.noticeType;
    if (current == InAppNoticeType.none || state.isDismissing) return;

    emit(state.copyWith(isDismissing: true));

    if (current == InAppNoticeType.accountBackup) {
      await noticeRepository.dismissAccountNotice();
    } else if (current == InAppNoticeType.proEnding) {
      final endsAt = state.proEndsAt;
      if (endsAt != null) await proEnding?.dismissPill(endsAt);
      await noticeRepository.markNoticeResolvedOrDismissed();
    } else {
      await noticeRepository.markNoticeResolvedOrDismissed();
    }

    _lastResolvedOrDismissedAt = DateTime.now();

    // Smooth exit delay before removing slot content
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!isClosed) {
      emit(
        state.copyWith(
          noticeType: InAppNoticeType.none,
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
    _identityChanges.removeListener(_onIdentityChanged);
    return super.close();
  }
}
