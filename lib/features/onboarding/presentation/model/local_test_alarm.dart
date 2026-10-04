import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

enum TestAlarmStatus {
  idle,
  ringing,
  success,
  failure,
}

/// Where the alarm the phone sets for itself stands.
@immutable
class LocalTestAlarmState {
  const LocalTestAlarmState({
    this.status = TestAlarmStatus.idle,
    this.countdownSeconds = LocalTestAlarm.delaySeconds,
    this.isCountingDown = false,
    this.canLaunch = false,
    this.alarm,
  });

  final TestAlarmStatus status;
  final int countdownSeconds;
  final bool isCountingDown;

  /// The countdown ran out: the alarm is ringing and its screen can open.
  final bool canLaunch;

  /// What the phone answered about alarm access on the last start. Null
  /// until a start has asked, or when the phone could not say.
  final AlarmAuthorization? alarm;

  bool get isFailure => status == TestAlarmStatus.failure;

  LocalTestAlarmState copyWith({
    TestAlarmStatus? status,
    int? countdownSeconds,
    bool? isCountingDown,
    bool? canLaunch,
    AlarmAuthorization? alarm,
  }) => LocalTestAlarmState(
    status: status ?? this.status,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    isCountingDown: isCountingDown ?? this.isCountingDown,
    canLaunch: canLaunch ?? this.canLaunch,
    alarm: alarm ?? this.alarm,
  );

  @override
  bool operator ==(Object other) =>
      other is LocalTestAlarmState &&
      status == other.status &&
      countdownSeconds == other.countdownSeconds &&
      isCountingDown == other.isCountingDown &&
      canLaunch == other.canLaunch &&
      alarm == other.alarm;

  @override
  int get hashCode =>
      Object.hash(status, countdownSeconds, isCountingDown, canLaunch, alarm);
}

typedef PeriodicTimerFactory =
    Timer Function(Duration period, void Function(Timer timer) onTick);

/// The alarm the phone sets for itself: a test of this phone only.
///
/// It never touches the server and it never starts by itself. The one copy
/// of this logic: the real ring step offers it as a fallback, and the test
/// step of the first shipped order runs it as its test.
class LocalTestAlarm {
  LocalTestAlarm({
    required this.host,
    required this.onChanged,
    this.saveCountdownEndsAt,
    PeriodicTimerFactory? periodic,
    DateTime Function()? now,
  }) : _periodic = periodic ?? Timer.periodic,
       _now = now ?? DateTime.now;

  /// Null in tests with no platform channel, where nothing can be set.
  final AlarmHost? host;

  /// Told about every change, with the whole new state.
  final void Function(LocalTestAlarmState state) onChanged;

  /// Remembers when the countdown ends, so it survives the app being
  /// killed. Null clears it. Left out on a replay, which saves nothing.
  final Future<void> Function(DateTime? endsAt)? saveCountdownEndsAt;

  final PeriodicTimerFactory _periodic;
  final DateTime Function() _now;

  /// How long the alarm waits before it rings. The countdown on screen and
  /// the alarm the OS holds are both set from this, so they cannot drift
  /// apart.
  static const delaySeconds = 5;

  LocalTestAlarmState _state = const LocalTestAlarmState();
  LocalTestAlarmState get state => _state;

  Timer? _timer;
  bool _disposed = false;

  void _set(LocalTestAlarmState next) {
    if (_disposed) return;
    _state = next;
    onChanged(next);
  }

  /// Sets the alarm for [delaySeconds] from now and starts the countdown.
  ///
  /// The OS holds the alarm, so it rings even if the app is backgrounded or
  /// killed before the countdown ends. When the platform cannot set one, the
  /// countdown is skipped rather than run in silence and then congratulate
  /// the user for a ring that never happened.
  ///
  /// [server] travels with the alarm. Android reads it back out of the alarm
  /// intent and drops the whole start when it is not an http or https URL.
  Future<void> start({required String server}) async {
    _timer?.cancel();

    // Read again on every start. The user may have just come back from
    // Settings, and the failure dialog explains itself from this value. The
    // idle status lets a second failure in a row open the dialog again.
    AlarmAuthorization? authorization;
    try {
      authorization = await host?.authorizationStatus();
    } on Object catch (_) {
      authorization = null;
    }
    if (_disposed) return;
    _set(
      LocalTestAlarmState(
        alarm: authorization ?? _state.alarm,
        countdownSeconds: _state.countdownSeconds,
      ),
    );

    final target = server.trim();
    final alarmHost = host;
    final scheduled =
        alarmHost != null &&
        target.isNotEmpty &&
        await alarmHost
            .scheduleAlarm(
              incidentId: phoneOnlyTestIncidentId,
              topic: phoneOnlyTestTopic,
              server: target,
              title: LocaleKeys.onboarding_connect_demo_alarm_title.tr(),
              body: LocaleKeys.onboarding_connect_demo_alarm_body.tr(),
              delaySeconds: delaySeconds,
              // The alarm has no incident on the server. The flag travels
              // with it to the Stop button on its notification, so that
              // button leaves no card behind either.
              handOverToStatusCard: false,
            )
            .catchError((_) => false);
    if (_disposed) return;

    if (!scheduled) {
      _set(
        _state.copyWith(
          status: TestAlarmStatus.failure,
          isCountingDown: false,
          countdownSeconds: delaySeconds,
        ),
      );
      return;
    }

    _set(
      _state.copyWith(
        status: TestAlarmStatus.ringing,
        isCountingDown: true,
        countdownSeconds: delaySeconds,
        canLaunch: false,
      ),
    );
    unawaited(
      saveCountdownEndsAt?.call(
        _now().add(const Duration(seconds: delaySeconds)),
      ),
    );
    _tick();
  }

  /// A countdown that was running when the app went away, with [secondsLeft]
  /// on the clock. The alarm itself is held by the OS, so this only catches
  /// the on-screen clock up.
  void resume(int secondsLeft) {
    if (secondsLeft <= 0) {
      // The alarm is already due or has rung. Go straight to the screen that
      // handles it rather than counting down to something in the past.
      _set(
        _state.copyWith(
          status: TestAlarmStatus.success,
          isCountingDown: false,
          countdownSeconds: 0,
          canLaunch: true,
        ),
      );
      unawaited(saveCountdownEndsAt?.call(null));
      return;
    }
    _set(
      _state.copyWith(
        status: TestAlarmStatus.ringing,
        isCountingDown: true,
        countdownSeconds: secondsLeft,
      ),
    );
    _tick();
  }

  /// Drives the on-screen clock. The alarm is already set; this only counts.
  void _tick() {
    _timer?.cancel();
    _timer = _periodic(const Duration(seconds: 1), (timer) {
      final next = _state.countdownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        unawaited(saveCountdownEndsAt?.call(null));
        _set(
          _state.copyWith(
            status: TestAlarmStatus.success,
            countdownSeconds: 0,
            isCountingDown: false,
            canLaunch: true,
          ),
        );
      } else {
        _set(_state.copyWith(countdownSeconds: next));
      }
    });
  }

  /// Stops the countdown and takes the alarm back.
  void cancel() {
    _timer?.cancel();
    final alarmHost = host;
    if (alarmHost != null) {
      // No handover. The alarm has no incident on the server, so an acked
      // card for it would sit there for good: it is ongoing, so it cannot
      // be swiped away, and its Done button would POST a close for an
      // incident that does not exist.
      unawaited(
        alarmHost
            .cancelAlarm(phoneOnlyTestIncidentId, handOverToStatusCard: false)
            .catchError((_) => false),
      );
    }
    unawaited(saveCountdownEndsAt?.call(null));
    _set(
      _state.copyWith(
        status: TestAlarmStatus.idle,
        isCountingDown: false,
        countdownSeconds: delaySeconds,
      ),
    );
  }

  /// The alarm screen was opened for a countdown that ran out.
  void launched() => _set(_state.copyWith(canLaunch: false));

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
