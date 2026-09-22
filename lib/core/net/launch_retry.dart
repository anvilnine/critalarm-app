import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:http/http.dart' as http;

/// How long `retryOnLaunch` waits before each of its five retries.
const launchRetryWaits = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 15),
];

/// The real wait: just sleeps. Tests pass their own `wait` so nothing sleeps.
Future<void> defaultLaunchWait(Duration duration) => Future.delayed(duration);

/// Runs [call] again after 1, 2, 5, 10 and 15 seconds when it fails with a
/// network error or a 5xx. Six attempts in total. Any other error stops it.
///
/// A network error is `SocketException`, `TimeoutException`, or
/// `http.ClientException`. An `ApiException` retries only on a 5xx, a 408, or
/// a 429; any other status code (a dead-credential 401, a 404, ...) is not a
/// launch hiccup and is rethrown right away, with no wait.
///
/// Every failed attempt, retried or not, writes one line through [log]:
/// `launch_call_failed call=<name> attempt=<n>
/// error=<runtimeType>[ status=<code>]`.
Future<T> retryOnLaunch<T>(
  String name,
  Future<T> Function() call, {
  required Future<void> Function(Duration) wait,
  required void Function(String line) log,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on Object catch (error) {
      final statusCode = error is ApiException ? error.statusCode : null;
      log(
        'launch_call_failed call=$name attempt=$attempt '
        'error=${error.runtimeType}'
        '${statusCode == null ? '' : ' status=$statusCode'}',
      );
      final retryable = _isRetryable(error, statusCode);
      if (!retryable || attempt > launchRetryWaits.length) rethrow;
      await wait(launchRetryWaits[attempt - 1]);
    }
  }
}

bool _isRetryable(Object error, int? statusCode) {
  if (statusCode != null) {
    return statusCode >= 500 || statusCode == 408 || statusCode == 429;
  }
  return error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;
}
