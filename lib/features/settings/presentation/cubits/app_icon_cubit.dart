import 'dart:async';

import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What a tap on an icon led to.
enum AppIconPick {
  /// The icon is on the home screen now.
  changed,

  /// It was already showing. Nothing happened.
  unchanged,

  /// It is a Pro icon and this device is not on Pro. The screen opens the
  /// paywall.
  locked,

  /// The platform refused. The old icon stays.
  failed,
}

/// The App icon picker, and the row on Appearance that leads to it.
///
/// Reads the plan again whenever it changes, so an icon unlocks the moment a
/// purchase goes through.
class AppIconCubit extends Cubit<AppIconState> {
  AppIconCubit({
    required this._readCurrent,
    required this._apply,
    required this._readUnlocked,
    Future<bool> Function()? readWelcomed,
    Future<void> Function()? markWelcomed,
    Stream<Object?>? unlockChanges,
    PlanChanges? planChanges,
  }) : _readWelcomed = readWelcomed ?? _alreadyWelcomed,
       _markWelcomed = markWelcomed ?? _noop,
       _planChanges = planChanges ?? appPlanChanges,
       super(const AppIconState()) {
    _planChanges.addListener(_onPlanChanged);
    _unlockSub = unlockChanges?.listen((_) => _onPlanChanged());
    unawaited(load());
  }

  final Future<AppIcon?> Function() _readCurrent;
  final Future<bool> Function(AppIcon icon) _apply;
  final Future<bool> Function() _readUnlocked;
  final Future<bool> Function() _readWelcomed;
  final Future<void> Function() _markWelcomed;
  final PlanChanges _planChanges;

  /// `FeatureAccess.changes` for the app icons in the app: the lock moved.
  StreamSubscription<Object?>? _unlockSub;
  bool _welcomeAsked = false;

  // Without a store the welcome never plays, so a test or a build that does
  // not wire one sees the plain screen.
  static Future<bool> _alreadyWelcomed() async => true;
  static Future<void> _noop() async {}

  void _onPlanChanged() => unawaited(load());

  /// Reads the icon on the home screen and whether Pro icons are open.
  Future<void> load() async {
    final current = await _readCurrent();
    if (isClosed) return;
    if (current == null) {
      emit(state.copyWith(status: AppIconStatus.unavailable));
      return;
    }
    final unlocked = await _safeUnlocked();
    if (isClosed) return;
    // Asked once per cubit: the constructor's load and a plan change can
    // overlap, and each must not claim the welcome.
    final ask = unlocked && !_welcomeAsked;
    if (ask) _welcomeAsked = true;
    final welcome = ask && !await _safeWelcomed();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: AppIconStatus.ready,
        current: current,
        unlocked: unlocked,
        welcome: welcome || state.welcome,
      ),
    );
    if (welcome) await _markWelcomed();
  }

  /// The screen played the welcome. It does not play again.
  void welcomePlayed() {
    if (state.welcome) emit(state.copyWith(welcome: false));
  }

  /// Switches to [icon], or says why it did not.
  Future<AppIconPick> pick(AppIcon icon) async {
    if (state.status != AppIconStatus.ready || state.saving != null) {
      return AppIconPick.unchanged;
    }
    if (state.isLocked(icon)) return AppIconPick.locked;
    if (icon == state.current) return AppIconPick.unchanged;

    emit(state.copyWith(saving: () => icon, failed: false));
    final ok = await _apply(icon);
    if (isClosed) return ok ? AppIconPick.changed : AppIconPick.failed;
    emit(
      state.copyWith(
        current: ok ? icon : null,
        saving: () => null,
        failed: !ok,
      ),
    );
    return ok ? AppIconPick.changed : AppIconPick.failed;
  }

  // A plan that cannot be read shows the Pro icons locked. The paywall is one
  // tap away and says the rest.
  Future<bool> _safeUnlocked() async {
    try {
      return await _readUnlocked();
    } on Object catch (error) {
      if (kDebugMode) debugPrint('CritAlarm: app_icon_unlocked $error');
      return false;
    }
  }

  Future<bool> _safeWelcomed() async {
    try {
      return await _readWelcomed();
    } on Object catch (error) {
      if (kDebugMode) debugPrint('CritAlarm: app_icon_welcomed $error');
      return true;
    }
  }

  @override
  Future<void> close() {
    _planChanges.removeListener(_onPlanChanged);
    unawaited(_unlockSub?.cancel());
    return super.close();
  }
}
