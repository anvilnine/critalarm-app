import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

/// Turns a transport-level exception into one plain line.
///
/// Without this the connect screen showed the user raw text like
/// "ClientException with SocketException: Failed host lookup ...
/// (OS Error: nodename nor servname provided, errno = 8)".
String networkFailureMessage(Object error) {
  if (error is TimeoutException) {
    return LocaleKeys.onboarding_connect_connect_timeout.tr();
  }
  if (error is SocketException || error is HttpException) {
    return LocaleKeys.onboarding_connect_network_unreachable.tr();
  }
  // http wraps the socket error in its own ClientException, so the type is
  // gone by the time it reaches us and the text is all that is left.
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection closed') ||
      text.contains('Network is unreachable')) {
    return LocaleKeys.onboarding_connect_network_unreachable.tr();
  }
  return text;
}

/// Turns a wire error code from the server into a sentence a user can read.
///
/// The server answers things like `{"error":"cap","cap":"critical_topics"}`,
/// and the bare word `cap` used to land under the Name field on New Topic. Any
/// code we have no sentence for falls back to one generic line, so a wire code
/// never reaches the screen.
String apiErrorMessage(String? wireCode, {String? cap}) {
  return switch (wireCode?.trim().toLowerCase()) {
    'cap' =>
      cap == null
          ? LocaleKeys.api_errors_cap_unnamed.tr()
          : LocaleKeys.api_errors_cap.tr(
              namedArgs: {'limit': CapReached(cap).label.toLowerCase()},
            ),
    'unauthorized' => LocaleKeys.api_errors_unauthorized.tr(),
    'invalid topic name' => LocaleKeys.api_errors_invalid_topic_name.tr(),
    'topic already exists' => LocaleKeys.api_errors_topic_already_exists.tr(),
    'rate limited' => LocaleKeys.api_errors_rate_limited.tr(),
    'invalid request' => LocaleKeys.api_errors_invalid_request.tr(),
    'not found' => LocaleKeys.api_errors_not_found.tr(),
    'topic must retain a token' =>
      LocaleKeys.api_errors_topic_must_retain_a_token.tr(),
    _ => LocaleKeys.api_errors_unknown.tr(),
  };
}

/// [apiErrorMessage] read straight off a [Failure].
///
/// `failure.message` is whatever the layer below put there: a server wire code
/// like `cap`, or the text of a caught exception. Neither belongs on screen,
/// so every cubit that shows an error runs it through here.
String failureMessage(Failure failure) => apiErrorMessage(
  failure.message,
  cap: CapReached.fromFailure(failure)?.name,
);

/// Default unauthenticated endpoint used to check connectivity for Crit Alarm
/// Cloud.
final Uri defaultConnectivityCheckUri = Uri.parse(
  'https://api.critalarm.app/v1/info',
);

/// Default timeout for the connectivity check probe.
const defaultConnectivityTimeout = Duration(seconds: 4);

/// Pure decision function evaluating whether a probe result indicates internet
/// reachability.
///
/// An unknown result (such as a timeout, SSL handshake anomaly, or server
/// error) is treated as online (`true`), not offline, so that transient issues
/// or unusual network configurations (private DNS, captive checks, high
/// latency) do not show a false offline notice. Only definitive offline errors
/// (such as network unreachable, network down, no route to host, or failed
/// host lookup) return `false`.
bool isOnlineFromProbe({
  int? statusCode,
  Object? error,
}) {
  if (statusCode != null) {
    // Any HTTP response means the device reached a remote server or proxy.
    return true;
  }
  if (error == null) {
    return true;
  }
  if (error is TimeoutException) {
    // Timeout could be high cellular latency or slow server response.
    // Treat unknown as online.
    return true;
  }
  if (error is HandshakeException ||
      error is TlsException ||
      error is CertificateException) {
    // TLS negotiation was attempted with a remote host or captive portal.
    // Treat unknown as online.
    return true;
  }
  // Check for definitive offline errors in SocketException or wrapped
  // ClientException.
  if (isDefinitiveOfflineError(error)) {
    return false;
  }
  // Any other unknown error is treated as online.
  return true;
}

/// Returns true only if [error] is a definitive indicator of no network route.
bool isDefinitiveOfflineError(Object error) {
  if (error is SocketException) {
    final osError = error.osError;
    if (osError != null) {
      final code = osError.errorCode;
      // Linux/Android: ENETDOWN (100), ENETUNREACH (101), EHOSTUNREACH (113)
      // macOS/iOS: ENETDOWN (50), ENETUNREACH (51), EHOSTUNREACH (65)
      // Windows: 10050, 10051, 10065
      if (code == 100 ||
          code == 101 ||
          code == 113 ||
          code == 50 ||
          code == 51 ||
          code == 65 ||
          code == 10050 ||
          code == 10051 ||
          code == 10065) {
        return true;
      }
    }
  }

  final text = error.toString();
  if (text.contains('Network is unreachable') ||
      text.contains('Network is down') ||
      text.contains('No route to host') ||
      text.contains('Failed host lookup')) {
    return true;
  }

  return false;
}

/// True when the device appears online and can reach the network.
///
/// Answers "can we reach the server we are about to use" by probing
/// [uri] (defaulting to [defaultConnectivityCheckUri], the unauthenticated
/// health check at `https://api.critalarm.app/v1/info`).
///
/// An unknown result (such as a timeout, SSL issue, or server error) is
/// treated as online, not offline, so that unusual network configurations do
/// not show a false offline notice.
Future<bool> hasInternet({
  Uri? uri,
  http.Client? client,
  Duration timeout = defaultConnectivityTimeout,
}) async {
  // Widget tests have no network and no business waiting for HTTP requests
  // to time out, which also leaves pending timers behind.
  if (Platform.environment.containsKey('FLUTTER_TEST') && client == null) {
    return true;
  }

  final targetUri = uri ?? defaultConnectivityCheckUri;
  final httpClient = client ?? http.Client();
  final shouldClose = client == null;

  try {
    final response = await httpClient
        .get(targetUri, headers: const {'accept': 'application/json'})
        .timeout(timeout);
    return isOnlineFromProbe(statusCode: response.statusCode);
  } on Object catch (e) {
    return isOnlineFromProbe(error: e);
  } finally {
    if (shouldClose) {
      httpClient.close();
    }
  }
}
