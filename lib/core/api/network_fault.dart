import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/api_exception.dart';

/// What kind of transport error a [NetworkFault] was. [server] is an error
/// answer from a server, such as a relay refusing a registration.
enum NetworkFaultKind { timeout, unreachable, server, other }

/// What is left of a transport error once its text is dropped.
///
/// An exception's text is written by whatever threw it, and it can quote
/// what was being sent, a credential included. Anything that travels on to
/// an outcome, a state or the screen carries this in its place.
final class NetworkFault implements Exception {
  const NetworkFault(this.kind, {this.server});

  factory NetworkFault.of(Object error) {
    if (error is NetworkFault) return error;
    if (error is ApiException) {
      final word = error.message.trim().toLowerCase();
      return NetworkFault(
        NetworkFaultKind.server,
        server: ApiException(
          statusCode: error.statusCode,
          message: knownWireErrors.contains(word) ? word : '',
          code: error.code,
          cap: error.cap,
        ),
      );
    }
    if (error is TimeoutException) {
      return const NetworkFault(NetworkFaultKind.timeout);
    }
    if (error is SocketException ||
        error is HttpException ||
        readsAsUnreachable(error.toString())) {
      return const NetworkFault(NetworkFaultKind.unreachable);
    }
    return const NetworkFault(NetworkFaultKind.other);
  }

  final NetworkFaultKind kind;

  /// For [NetworkFaultKind.server], what the app has words for: the status,
  /// the numeric code, the cap, and the error word when it is one of
  /// [knownWireErrors]. Any other text the server wrote is dropped.
  final ApiException? server;

  /// The error words of api.md §1.8 that the app turns into its own line.
  static const knownWireErrors = {
    'cap',
    'unauthorized',
    'invalid topic name',
    'topic already exists',
    'message too large',
    'rate limited',
    'invalid priority',
    'invalid request',
    'incident state conflict',
    'scheduled delivery not supported',
    'streaming not supported',
    'not found',
    'pack',
    'tier',
    'invalid base_url',
    'challenge failed',
    'registration closed',
    'topic mismatch',
    'topic must retain a token',
  };

  // http wraps the socket error in its own ClientException, so the type is
  // gone by the time it reaches us and the text is all that is left.
  static bool readsAsUnreachable(String text) =>
      text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection closed') ||
      text.contains('Network is unreachable');

  @override
  String toString() => 'NetworkFault(${kind.name})';
}
