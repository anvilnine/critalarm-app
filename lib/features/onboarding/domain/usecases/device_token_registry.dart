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
/// when nothing changed. The 24 hours count from the last call the relay
/// accepted for this device, relay and token, never from a failed attempt. A
/// confirmation that failed is therefore due again on the next launch, even if
/// the process was killed before the in-memory [launchCallsPending] flag could
/// be read, and on every resume until one succeeds. That is one call per
/// resume: a refusal is not retried inside a call, and a network error or 5xx
/// uses the usual launch retry waits.
///
/// Calls never overlap. While one is in flight a request for a particular
/// token, or a forced one, is remembered and sent right after it, and the
/// newest token wins. A plain request (a resume, a launch) joins whatever is
/// already running or waiting, so two resumes close together send once.
///
/// Every call, and how it ended, is kept in a [RelayConfirmationStore] for
/// anything that wants to say whether the relay holds a good token. Nothing
/// here throws: the callers on launch and resume do not await it.
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
    Future<RelayConfirmationScope?> Function(String token)? scopeFor,
  }) : confirmations = confirmations ?? RelayConfirmationStore(prefs),
       _now = now ?? DateTime.now,
       _scopeFor = scopeFor ?? _unscoped;

  static Future<RelayConfirmationScope?> _unscoped(String token) async =>
      RelayConfirmationScope.unscoped;

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

  /// Names the device, relay and token a call is about. Null when there is
  /// no server to name (no saved session).
  final Future<RelayConfirmationScope?> Function(String token) _scopeFor;

  StreamSubscription<String>? _rotations;

  bool _launchCallsPending = false;
  _Request? _inFlight;
  _Request? _queued;

  /// True when the last registration call failed even after
  /// `retryOnLaunch` gave up. Read on resume so a healthy app is not
  /// re-registered on every foreground. It lives in memory only: a fresh
  /// process works out what is owed from the stored record instead.
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
  /// when one is due. A resume inside the 24 hours makes no call.
  Future<void> onResumed() async {
    if (_launchCallsPending) return retryIfPending();
    await _sync(null, confirmWhenDue: true);
  }

  /// Sends the current token now, whatever was sent today. For a button.
  /// True when the relay accepted it.
  Future<bool> confirmNow() => _sync(null, force: true);

  /// The scope of the token this phone would send now, or null when there is
  /// none to name. What a reader compares a stored record against.
  Future<RelayConfirmationScope?> currentScope() async {
    try {
      final token =
          prefs.getString(pendingNativeTokenKey) ?? await tokens.getToken();
      if (token.isEmpty) return null;
      return await _scopeFor(token);
    } on Object catch (_) {
      return null;
    }
  }

  /// Sends [token] to the relay, or reads the current one when null.
  ///
  /// Returns true when a call was made and the relay took it. Failures are
  /// swallowed: registration is retried on the next launch or the next
  /// rotation.
  Future<bool> syncToken(String? token) => _sync(token);

  Future<bool> _sync(
    String? token, {
    bool force = false,
    bool confirmWhenDue = false,
  }) {
    final running = _inFlight;
    if (running == null) {
      final request = _Request(
        token,
        force: force,
        confirmWhenDue: confirmWhenDue,
      );
      _inFlight = request;
      unawaited(_drain(request));
      return request.done.future;
    }
    final queued = _queued;
    // A plain request reads the current token and sends only when something
    // changed or a day has passed. What is running or waiting already covers
    // that.
    if (token == null && !force) return (queued ?? running).done.future;
    final next = queued ?? (_queued = _Request(null));
    next
      ..token = token ?? next.token
      ..force = next.force || force
      ..confirmWhenDue = next.confirmWhenDue || confirmWhenDue;
    return next.done.future;
  }

  /// Runs [first], then whatever was asked for meanwhile, one at a time.
  Future<void> _drain(_Request first) async {
    var current = first;
    while (true) {
      var result = false;
      try {
        result = await _execute(current);
      } on Object catch (error) {
        log('registration_failed error=${error.runtimeType}');
      }
      current.done.complete(result);
      final next = _queued;
      _queued = null;
      _inFlight = next;
      if (next == null) return;
      current = next;
    }
  }

  Future<bool> _execute(_Request request) async {
    String resolved;
    try {
      resolved =
          request.token ??
          prefs.getString(pendingNativeTokenKey) ??
          await tokens.getToken();
    } on Object catch (_) {
      return false;
    }
    if (resolved.isEmpty) return false;

    final kind = tokens.kind.name;
    final scope = await _scopeOf(resolved);
    final unchanged =
        prefs.getString(lastTokenKey) == resolved &&
        prefs.getString(lastVersionKey) == appVersion &&
        prefs.getString(lastKindKey) == kind;
    final due = request.confirmWhenDue && _confirmationDue(scope);
    if (unchanged && !request.force && !due) return false;

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
      await _record(_outcomeOf(error), scope);
      return false;
    }
    _launchCallsPending = false;
    await prefs.setString(lastTokenKey, resolved);
    await prefs.setString(lastVersionKey, appVersion);
    await prefs.setString(lastKindKey, kind);
    await prefs.remove(pendingNativeTokenKey);
    await _record(RelayAttemptOutcome.accepted, scope);
    return true;
  }

  Future<RelayConfirmationScope?> _scopeOf(String token) async {
    try {
      return await _scopeFor(token);
    } on Object catch (_) {
      return null;
    }
  }

  /// The record is for readers. A phone that cannot write it still has a
  /// token on the relay, so a failed write is logged and nothing else.
  Future<void> _record(
    RelayAttemptOutcome outcome,
    RelayConfirmationScope? scope,
  ) async {
    if (scope == null) return;
    try {
      await confirmations.record(_now(), outcome, scope);
    } on Object catch (error) {
      log('confirmation_record_failed error=${error.runtimeType}');
    }
  }

  /// Due when the relay has not accepted this device, relay and token inside
  /// [confirmEvery]. Failed attempts do not move it.
  bool _confirmationDue(RelayConfirmationScope? scope) {
    final accepted = scope == null ? null : confirmations.confirmedAtFor(scope);
    if (accepted == null) return true;
    final age = _now().difference(accepted);
    // A clock set back counts as due: the stamp cannot be trusted.
    return age.isNegative || age >= confirmEvery;
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

/// One ask of [DeviceTokenRegistry]. Later asks fold into a waiting one.
final class _Request {
  _Request(this.token, {this.force = false, this.confirmWhenDue = false});

  /// The token to send, or null to read the current one when it runs.
  String? token;
  bool force;
  bool confirmWhenDue;
  final Completer<bool> done = Completer<bool>();
}
