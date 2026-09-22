import 'dart:async';

import 'package:critalarm/core/net/launch_retry.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
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
final class DeviceTokenRegistry {
  DeviceTokenRegistry({
    required this.prefs,
    required this.register,
    required this.tokens,
    required this.appVersion,
    this.wait = defaultLaunchWait,
    this.log = _defaultLog,
  });

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
    await syncToken(null);
  }

  Future<void> stop() async {
    await _rotations?.cancel();
    _rotations = null;
  }

  /// Resume calls this. Runs the registration call again, but only when the
  /// last one ended in failure.
  Future<void> retryIfPending() async {
    if (!_launchCallsPending) return;
    await syncToken(null);
  }

  /// Sends [token] to the relay, or reads the current one when null.
  ///
  /// Returns true when a call was made. Failures are swallowed: registration is
  /// retried on the next launch or the next rotation.
  Future<bool> syncToken(String? token) async {
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
    if (unchanged) return false;

    try {
      await retryOnLaunch(
        'device_registration',
        () => register(appVersion: appVersion, pushToken: resolved),
        wait: wait,
        log: log,
      );
    } on Object catch (_) {
      _launchCallsPending = true;
      return false;
    }
    _launchCallsPending = false;
    await prefs.setString(lastTokenKey, resolved);
    await prefs.setString(lastVersionKey, appVersion);
    await prefs.setString(lastKindKey, kind);
    await prefs.remove(pendingNativeTokenKey);
    return true;
  }
}
