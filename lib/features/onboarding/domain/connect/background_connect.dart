import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:flutter/foundation.dart';

/// Where a connect that runs behind the user stands.
enum BackgroundConnectStatus {
  /// Nothing was asked for, or it was cancelled.
  idle,

  /// A try is on its way, or the server was briefly down and the next try is
  /// scheduled.
  connecting,

  /// The phone has no route to the server. It is tried again by itself.
  waitingForNetwork,

  /// The server answered, but the phone has not handed over its push token
  /// yet, so the device cannot be registered. Tried again by itself.
  waitingForPushToken,

  /// The connection is saved.
  connected,

  /// It will not fix itself. See [BackgroundConnectState.failure].
  failed,
}

/// Why a connect gave up.
enum BackgroundConnectFailure {
  /// The server runs a major version this app does not know.
  versionUnsupported,

  /// The server is someone's own and wants an admin token, which only the
  /// connect step can ask for.
  needsAdminToken,

  /// The server or the relay answered an error a retry will not change.
  refused,
}

@immutable
class BackgroundConnectState {
  const BackgroundConnectState({
    this.status = BackgroundConnectStatus.idle,
    this.serverUrl,
    this.failure,
    this.serverVersion,
  });

  final BackgroundConnectStatus status;

  /// The server being connected to. Null when idle.
  final String? serverUrl;

  /// Set when [status] is [BackgroundConnectStatus.failed].
  final BackgroundConnectFailure? failure;

  /// The version the server reported, for
  /// [BackgroundConnectFailure.versionUnsupported].
  final String? serverVersion;

  /// Asked for and not landed yet. It will finish, or fail, by itself.
  bool get isPending =>
      status == BackgroundConnectStatus.connecting ||
      status == BackgroundConnectStatus.waitingForNetwork ||
      status == BackgroundConnectStatus.waitingForPushToken;

  bool get isConnected => status == BackgroundConnectStatus.connected;

  bool get isFailed => status == BackgroundConnectStatus.failed;

  @override
  bool operator ==(Object other) =>
      other is BackgroundConnectState &&
      status == other.status &&
      serverUrl == other.serverUrl &&
      failure == other.failure &&
      serverVersion == other.serverVersion;

  @override
  int get hashCode => Object.hash(status, serverUrl, failure, serverVersion);

  @override
  String toString() =>
      'BackgroundConnectState(${status.name}, $serverUrl, ${failure?.name})';
}

/// Connects to a server while the user carries on with setup.
///
/// One object for the whole app run, because the screen that starts a
/// connect is gone before it lands. [start] writes the intent to disk first
/// and answers at once. The three round trips (server info, device
/// registration, saving the connection) run behind it. A try that fails
/// because the network or the push token is not there yet stays on disk and
/// is tried again on a timer, on resume and on the next launch.
///
/// Nothing here throws. The outcome is on [state] and [stream], and whoever
/// is on screen shows it.
class BackgroundConnect {
  BackgroundConnect({
    required this._intents,
    required this._getServerInfo,
    required this._establishSession,
    required this._saveConnection,
    this._tokens,
    this.onConnected,
    DateTime Function()? clock,
    this.tickInterval = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;

  /// First retry waits this long; each later one doubles it.
  static const baseBackoff = Duration(seconds: 2);

  /// Retries never wait longer than this between attempts.
  static const maxBackoff = Duration(minutes: 5);

  final ConnectIntentStore _intents;
  final GetServerInfoUsecase _getServerInfo;
  final EstablishApiSessionUsecase _establishSession;
  final SaveConnectionUsecase _saveConnection;

  /// Where the push token comes from. Null on a platform with no push, where
  /// the connect does not wait for one.
  final PushTokenProvider? _tokens;

  /// Called once the connection is saved, so the rest of the app can load
  /// from the new server.
  final Future<void> Function()? onConnected;

  final DateTime Function() _clock;
  final Duration tickInterval;

  final _states = StreamController<BackgroundConnectState>.broadcast();
  BackgroundConnectState _state = const BackgroundConnectState();

  Timer? _ticker;
  StreamSubscription<String>? _tokenArrivals;
  Future<void>? _running;

  /// Goes up whenever the intent is replaced or cancelled, so a try that was
  /// already on its way knows its answer is no longer wanted.
  int _generation = 0;

  BackgroundConnectState get state => _state;

  /// Every change of [state]. Does not replay the current one.
  Stream<BackgroundConnectState> get stream => _states.stream;

  /// Whether the retry timer is running.
  @visibleForTesting
  bool get hasTimer => _ticker != null;

  /// Completes when no try is on its way.
  @visibleForTesting
  Future<void> get settled async {
    while (_running != null) {
      await _running;
    }
  }

  /// The user asked to connect to [serverUrl]. Answers once the intent is on
  /// disk; the connect itself carries on behind.
  ///
  /// Asking again for the same server while it is still pending starts no
  /// second run.
  Future<void> start(String serverUrl) async {
    if (_state.isPending && _intents.read()?.serverUrl == serverUrl) return;
    _generation++;
    await _intents.save(ConnectIntent(serverUrl: serverUrl));
    _emit(
      BackgroundConnectState(
        status: BackgroundConnectStatus.connecting,
        serverUrl: serverUrl,
      ),
    );
    _watch();
    unawaited(_attempt(afterCurrent: true));
  }

  /// Launch. Picks up an intent the last run left on disk.
  Future<void> resumeSaved() async {
    final intent = _intents.read();
    if (intent == null) return;
    _emit(
      BackgroundConnectState(
        status: BackgroundConnectStatus.connecting,
        serverUrl: intent.serverUrl,
      ),
    );
    _watch();
    await _attempt();
  }

  /// Tries now, whatever the retry time says. For the moments something may
  /// have just changed: the app came back to the front, the push token
  /// arrived, the user answered the permission steps.
  Future<void> retryNow() async {
    if (_intents.read() == null) return;
    await _attempt();
  }

  /// What the timer runs: tries only once the retry time has passed.
  @visibleForTesting
  Future<void> tick() async {
    final intent = _intents.read();
    if (intent == null) {
      _unwatch();
      return;
    }
    if (intent.nextAttemptAtMs > _clock().millisecondsSinceEpoch) return;
    await _attempt();
  }

  /// Drops the pending connect. For a user who disconnects or picks another
  /// server.
  Future<void> cancel() async {
    _generation++;
    _unwatch();
    await _intents.clear();
    _emit(const BackgroundConnectState());
  }

  Future<void> dispose() async {
    _generation++;
    _unwatch();
    await _states.close();
  }

  void _watch() {
    _ticker ??= Timer.periodic(tickInterval, (_) => unawaited(tick()));
    if (_tokenArrivals != null) return;
    try {
      // The push token turning up is the moment a connect that was waiting
      // for it can finish.
      _tokenArrivals = _tokens?.tokenRefreshes.listen(
        (_) => unawaited(retryNow()),
        onError: (Object _) {},
      );
    } on Object catch (_) {
      // A build with no push service has no stream to listen to. The timer
      // still retries.
    }
  }

  void _unwatch() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_tokenArrivals?.cancel());
    _tokenArrivals = null;
  }

  void _emit(BackgroundConnectState next) {
    if (next == _state) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// One try at a time. A call that arrives while one is running shares it,
  /// unless [afterCurrent] asks for a fresh one once that is done.
  Future<void> _attempt({bool afterCurrent = false}) async {
    final running = _running;
    if (running != null) {
      await running;
      if (!afterCurrent) return;
      // Somebody else may have started the next one while this waited.
      if (_running != null) return _attempt();
    }
    final run = _attemptOnce();
    _running = run;
    try {
      await run;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  Future<void> _attemptOnce() async {
    final intent = _intents.read();
    if (intent == null) return;
    final generation = _generation;
    bool isStale() => generation != _generation;

    final uri = Uri.tryParse(intent.serverUrl);
    if (uri == null) return _fail(BackgroundConnectFailure.refused);

    final infoResult = await _getServerInfo(uri);
    if (isStale()) return;
    final info = infoResult.getOrNull();
    if (info == null) {
      final failure = infoResult.exceptionOrNull();
      if (failure is ApiFailure) {
        return _afterStatus(intent, failure.statusCode);
      }
      // Anything that is not an answer from the server is the network.
      return _retryLater(intent, BackgroundConnectStatus.waitingForNetwork);
    }

    if (!ServerInfoValidation.isSemverCompatible(info.version)) {
      return _fail(
        BackgroundConnectFailure.versionUnsupported,
        serverVersion: info.version,
      );
    }
    final ServerMode mode;
    try {
      mode = ServerMode.fromWireValue(info.mode);
    } on FormatException {
      return _fail(BackgroundConnectFailure.refused);
    }
    if (mode == ServerMode.selfhosted) {
      return _fail(BackgroundConnectFailure.needsAdminToken);
    }

    // The device is registered with its push token, so the token comes
    // first. A phone that has not handed one over yet is not a failure: the
    // connect waits and finishes when it arrives.
    String? pushToken;
    final tokens = _tokens;
    if (tokens != null) {
      try {
        pushToken = await tokens.getToken();
      } on Object catch (_) {
        if (isStale()) return;
        return _retryLater(
          intent,
          BackgroundConnectStatus.waitingForPushToken,
        );
      }
      if (isStale()) return;
    }

    try {
      final session = await _establishSession(info, '', pushToken: pushToken);
      if (isStale()) return;
      final saved = await _saveConnection(
        ServerConnection(
          serverUrl: info.baseUrl,
          adminToken: session.managementCredential,
        ),
      );
      if (isStale()) return;
      if (saved.isError()) {
        return _retryLater(intent, BackgroundConnectStatus.connecting);
      }
    } on ApiException catch (error) {
      if (isStale()) return;
      return _afterStatus(intent, error.statusCode);
    } on Object catch (error) {
      if (isStale()) return;
      // The relay answered without a device token. Asking again gets the
      // same answer.
      if (error is StateError) return _fail(BackgroundConnectFailure.refused);
      // Offline, DNS failure, timeout: keep it and try later.
      return _retryLater(intent, BackgroundConnectStatus.waitingForNetwork);
    }

    await _intents.clear();
    _unwatch();
    _emit(
      BackgroundConnectState(
        status: BackgroundConnectStatus.connected,
        serverUrl: info.baseUrl,
      ),
    );
    try {
      await onConnected?.call();
    } on Object catch (error) {
      debugPrint('CritAlarmConnect: on_connected_failed error=$error');
    }
  }

  /// 408, 429 and 5xx are worth trying again. Any other status will not
  /// change on a retry.
  Future<void> _afterStatus(ConnectIntent intent, int status) {
    if (status == 408 || status == 429 || status >= 500) {
      return _retryLater(intent, BackgroundConnectStatus.connecting);
    }
    return _fail(BackgroundConnectFailure.refused);
  }

  Future<void> _retryLater(
    ConnectIntent intent,
    BackgroundConnectStatus status,
  ) async {
    final attempts = intent.attempts + 1;
    await _intents.save(
      intent.copyWith(
        attempts: attempts,
        nextAttemptAtMs: _clock()
            .add(_backoff(attempts))
            .millisecondsSinceEpoch,
      ),
    );
    _emit(BackgroundConnectState(status: status, serverUrl: intent.serverUrl));
  }

  Future<void> _fail(
    BackgroundConnectFailure failure, {
    String? serverVersion,
  }) async {
    final serverUrl = _intents.read()?.serverUrl ?? _state.serverUrl;
    await _intents.clear();
    _unwatch();
    _emit(
      BackgroundConnectState(
        status: BackgroundConnectStatus.failed,
        serverUrl: serverUrl,
        failure: failure,
        serverVersion: serverVersion,
      ),
    );
  }

  /// Wait before attempt [attempts], doubling each time up to [maxBackoff].
  static Duration _backoff(int attempts) {
    // Past 20 doublings the shift is far beyond the cap anyway.
    final doublings = attempts > 20 ? 20 : attempts - 1;
    final millis = baseBackoff.inMilliseconds * (1 << doublings);
    return millis >= maxBackoff.inMilliseconds
        ? maxBackoff
        : Duration(milliseconds: millis);
  }
}
