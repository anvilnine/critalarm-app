import 'dart:async';
import 'dart:io';

/// What kind of transport error a [NetworkFault] was.
enum NetworkFaultKind { timeout, unreachable, other }

/// What is left of a transport error once its text is dropped.
///
/// An exception's text is written by whatever threw it, and it can quote
/// what was being sent, a credential included. Anything that travels on to
/// an outcome, a state or the screen carries this in its place.
final class NetworkFault implements Exception {
  const NetworkFault(this.kind);

  factory NetworkFault.of(Object error) {
    if (error is NetworkFault) return error;
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
