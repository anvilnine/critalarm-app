import 'dart:async';

import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Picks the one reminder Home pins above the tab bar, following the
/// anti-fatigue cooldown and the 7-day snoozing rules:
/// 1. Pro ends soon (cancelled plan, 5-day snooze)
/// 2. Account backup prompt (Engagement, 7-day snooze, only once the user
///    owns a topic and a day has passed since the first one)
///
/// Anything that says an alarm may not ring (no server, a missing
/// permission, a missed alarm, a stopped weekly check, a phone update) is
/// the status card's job and never a notice.
///
/// Nothing shows before setup is done (`SetupGate`): onboarding finished,
/// including the create-your-first-topic screens, and the Topics Feature
/// Guide seen or skipped. Home loads again when a guide ends. Nothing shows
/// with no server saved either.
///
/// Pro is not only a reminder. It is also a sheet, asked for by `ProAskRules`
/// in `lib/features/in_app_notices/domain/pro_ask_rules.dart` at a moment
/// that earns the ask.
class InAppNoticeCubit extends Cubit<InAppNoticeState> {
  InAppNoticeCubit({
    required this.getConnectionUsecase,
    required this.identityRepository,
    required this.accountRepository,
    required this.noticeRepository,
    required Future<List<Topic>?> Function() readTopics,
    this.proEnding,
    AccountIdentityChanges? identityChanges,
    Future<bool> Function()? isSetupDone,
    DateTime Function()? clock,
    this.cooldownDuration = const Duration(seconds: 45),
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _readTopics = readTopics,
       _clock = clock ?? DateTime.now,
       _identityChanges = identityChanges ?? appAccountIdentityChanges,
       // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone,
       super(const InAppNoticeState()) {
    _identityChanges.addListener(_onIdentityChanged);
  }

  final GetConnectionUsecase getConnectionUsecase;
  final IdentityRepository identityRepository;
  final AccountRepository accountRepository;
  final InAppNoticeRepository noticeRepository;
  final ProEnding? proEnding;
  final AccountIdentityChanges _identityChanges;
  final Duration cooldownDuration;

  /// The topics on the connected server, or null when the read failed.
  final Future<List<Topic>?> Function() _readTopics;

  final DateTime Function() _clock;

  /// How long the backup notice waits after the user's first topic.
  static const Duration backupWait = Duration(hours: 24);

  /// `SetupGate.isDone` in the app. Null in tests that do not care, and
  /// counts as done.
  final Future<bool> Function()? _isSetupDone;

  Timer? _cooldownTimer;
  DateTime? _lastResolvedOrDismissedAt;

  /// Somebody signed in, signed out, linked another provider or deleted the
  /// account. The backup notice reads the identity, so ask again right away
  /// instead of waiting for a resume or a pull to refresh.
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
    await _evaluate();
  }

  Future<void> _evaluate({bool isResumed = false}) async {
    if (isClosed || state.isDismissing) return;

    // Nothing before setup is done: not during onboarding, and not before
    // the Topics guide has been seen. The state is left as it is rather than
    // set to none: before the Topics guide it is still the first none, and
    // while a later guide is up Home hides the notice itself.
    final isSetupDone =
        await (_isSetupDone?.call() ?? Future<bool>.value(true));
    if (isClosed || !isSetupDone) return;

    // With no server saved there is nothing to remind about. The status card
    // says so.
    final connResult = await getConnectionUsecase(const NoParams());
    if (isClosed) return;
    final conn = connResult.getOrNull();
    final hasServer = conn != null && conn.serverUrl.trim().isNotEmpty;
    if (!hasServer) {
      emit(state.copyWith(noticeType: InAppNoticeType.none));
      return;
    }

    // Check active cooldown
    if (!isResumed && _lastResolvedOrDismissedAt != null) {
      final elapsed = DateTime.now().difference(_lastResolvedOrDismissedAt!);
      if (elapsed < cooldownDuration) {
        emit(state.copyWith(noticeType: InAppNoticeType.none));
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

    // The topic list feeds the backup notice. A failed read (null) counts as
    // unknown, so it does not show and nothing is stamped.
    final topics = await _readTopics();
    if (isClosed) return;
    final ownsTopic = topics != null && topics.isNotEmpty;
    // Persisted, set once: the backup notice waits a day from here. An
    // install that already has topics gets the stamp on its first pass.
    if (ownsTopic) await noticeRepository.markFirstTopicOwned();

    // Pro ends soon: a cancelled Pro plan that has not ended yet.
    final ending = await proEnding?.read();
    if (isClosed) return;
    if (ending != null && ending.showPill) {
      emit(
        state.copyWith(
          noticeType: InAppNoticeType.proEnding,
          proEndsAt: ending.endsAt,
        ),
      );
      return;
    }

    // Account backup.
    // About what the server is, not about plans: a self-hosted server has
    // no accounts to back topics up to.
    final mode = await accountRepository.readServerMode();
    final canHaveAccounts =
        mode != ServerMode.selfhosted; // access-ok: accounts exist
    final firstTopicAt = noticeRepository.getFirstTopicOwnedAt();
    final waitedLongEnough =
        firstTopicAt != null && _clock().difference(firstTopicAt) >= backupWait;
    if (canHaveAccounts && ownsTopic && waitedLongEnough) {
      final identity = await identityRepository.readIdentity();
      if (identity == null) {
        final accountDismissedAt = noticeRepository
            .getAccountNoticeDismissedAt();
        final isAccountSnoozed =
            accountDismissedAt != null &&
            _clock().difference(accountDismissedAt).inDays < 7;
        if (!isAccountSnoozed) {
          emit(state.copyWith(noticeType: InAppNoticeType.accountBackup));
          return;
        }
      }
    }

    emit(state.copyWith(noticeType: InAppNoticeType.none));
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
    }

    _lastResolvedOrDismissedAt = DateTime.now();

    // Smooth exit delay before removing slot content
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!isClosed) {
      emit(
        state.copyWith(
          noticeType: InAppNoticeType.none,
          isDismissing: false,
        ),
      );
      _startCooldownTimer();
    }
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    _identityChanges.removeListener(_onIdentityChanged);
    return super.close();
  }
}
