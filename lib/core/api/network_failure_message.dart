import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

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
    _ => LocaleKeys.api_errors_unknown.tr(),
  };
}

/// True when the device has no route out at all.
///
/// Onboarding uses it to say so up front instead of letting the user tap
/// Connect and read a failure. It never blocks: the user can still carry on.
Future<bool> hasInternet() async {
  // A widget test has no network and no business waiting three seconds for a
  // DNS lookup to time out, which also leaves a pending timer behind.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
  try {
    final result = await InternetAddress.lookup(
      'one.one.one.one',
    ).timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on Object {
    return false;
  }
}
