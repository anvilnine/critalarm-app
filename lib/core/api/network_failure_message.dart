import 'dart:async';
import 'dart:io';

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
