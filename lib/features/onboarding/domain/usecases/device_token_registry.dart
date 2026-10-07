import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:critalarm/core/net/launch_retry.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _defaultLog(String line) => debugPrint('CritAlarmDeviceRegistry: $line');

/// Keeps the relay's copy of this handset's push token current.
///
/// Runs once on launch and again whenever FCM or APNs hands out a new token
/// (api.md §4.2). The token last accepted by the relay is kept on disk so a
/// launch that changed nothing does not spend a request. A launch call that
/// still fails after `retryOnLaunch` gives up is retried once more on the
/// next resume, see [launchCallsPending].
///
/// The relay can lose a token without the phone knowing, so once every
/// [confirmEvery] a launch or a resume sends the current token again even
/// when nothing changed. Every call, and how it ended, is kept in a
/// [RelayConfirmationStore] for anything that wants to say whether the relay
/// holds a good token.
final class DeviceTokenRegistry {
  DeviceTokenRegistry({
    required this.prefs,
    required this.register,
    required this.tokens,
    required this.appVersion,
    this.wait = defaultLaunchWait,
    this.log = _defaultLog,
    this.callLog,
    RelayConfirmationStore? confirmations,
    DateTime Function()? now,
  }) : confirmations = confirmations ?? RelayConfirmationStore(prefs),
       _now = now ?? DateTime.now;

  /// The most often an unchanged token is sent again.
  static const confirmEvery = Duration(hours: 24);

  static const lastTokenKey = 'relay_push_token';
  static const lastVersionKey = 'relay_app_version';

  /// Which push service the registered token came from. iOS registers an APNs
  /// token and Android an FCM one, so a build that switches kinds has to
  /// register again even when nothing else moved.
  static const lastKindKey = 'relay_push_token_kind';

  /// Where the native FCM service leaves a token that arrived while Dart was
  /// not running. Written by `CritAlarmMessagingService.onNewToken`.
  static const pendingNativeTokenKey = 'flutter.pending_push_token';

  final SharedPreferences prefs;
  final RegisterDeviceUsecase register;
  final PushTokenProvider tokens;
  final String appVersion;
  final Future<void> Function(Duration) wait;
  final void Function(String line) log;
  final LaunchCallLog? callLog;
  final RelayConfirmationStore confirmations;
  final DateTime Function() _now;

  StreamSubscription<String>? _rotations;

  bool _launchCallsPending = false;

  /// True when the last registration call failed even after
  /// `retryOnLaunch` gave up. Read on resume so a healthy app is not
  /// re-registered on every foreground.
  bool get launchCallsPending => _launchCallsPending;

  /// Registers on launch and starts watching for rotations.
  Future<void> start() async {
    await _rotations?.cancel();
    _rotations = tokens.tokenRefreshes.listen(
      (token) => unawaited(syncToken(token)),
    );
    await _sync(null, confirmWhenDue: true);
  }

  Future<void> stop() async {
    await _rotations?.cancel();
    _rotations = null;
  }

  /// Resume calls this. Runs the registration call again, but only when the
  /// last one ended in failure.
  Future<void> retryIfPending() async {
    if (!_launchCallsPending) return;
    // A failed call is owed even when the token has not changed since.
    await _sync(null, force: true);
  }

  /// What a resume calls: the retry above, or else the daily confirmation
  /// when one is due. A resume inside the 24 hours reads nothing and makes
  /// no call.
  Future<void> onResumed() async {
    if (_launchCallsPending) return retryIfPending();
    if (!_confirmationDue()) return;
    await _sync(null, confirmWhenDue: true);
  }

  /// Sends the current token now, whatever was sent today. For a button.
  /// True when the relay accepted it.
  Future<bool> confirmNow() => _sync(null, force: true);

  bool _confirmationDue() {
    final last = confirmations.lastAttemptAt;
    if (last == null) return true;
    final age = _now().difference(last);
    // A clock set back counts as due: the stamp cannot be trusted.
    return age.isNegative || age >= confirmEvery;
  }

  /// Sends [token] to the relay, or reads the current one when null.
  ///
  /// Returns true when a call was made. Failures are swallowed: registration is
  /// retried on the next launch or the next rotation.
  Future<bool> syncToken(String? token) => _sync(token);

  Future<bool> _sync(
    String? token, {
    bool force = false,
    bool confirmWhenDue = false,
  }) async {
    String resolved;
    try {
      resolved =
          token ??
          prefs.getString(pendingNativeTokenKey) ??
          await tokens.getToken();
    } on Object catch (_) {
      return false;
    }
    if (resolved.isEmpty) return false;

    final kind = tokens.kind.name;
    final unchanged =
        prefs.getString(lastTokenKey) == resolved &&
        prefs.getString(lastVersionKey) == appVersion &&
        prefs.getString(lastKindKey) == kind;
    final due = confirmWhenDue && _confirmationDue();
    if (unchanged && !force && !due) return false;

    try {
      await retryOnLaunch(
        'device_registration',
        () => register(appVersion: appVersion, pushToken: resolved),
        wait: wait,
        log: log,
        callLog: callLog,
      );
    } on Object catch (error) {
      _launchCallsPending = true;
      await confirmations.record(_now(), _outcomeOf(error));
      return false;
    }
    _launchCallsPending = false;
    await confirmations.record(_now(), RelayAttemptOutcome.accepted);
    await prefs.setString(lastTokenKey, resolved);
    await prefs.setString(lastVersionKey, appVersion);
    await prefs.setString(lastKindKey, kind);
    await prefs.remove(pendingNativeTokenKey);
    return true;
  }

  /// A 4xx means the relay heard the token and said no. Anything else, a
  /// network error or a 5xx, says nothing about the token itself. A 408 is a
  /// timeout, so it is the second kind.
  static RelayAttemptOutcome _outcomeOf(Object error) {
    if (error is ApiException &&
        error.statusCode >= 400 &&
        error.statusCode < 500 &&
        error.statusCode != 408) {
      return RelayAttemptOutcome.refused;
    }
    return RelayAttemptOutcome.failed;
  }
}
