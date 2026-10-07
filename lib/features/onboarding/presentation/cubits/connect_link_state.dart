import 'package:flutter/foundation.dart';

enum ConnectLinkPhase { ready, connecting, failed, connected }

/// What the connect sheet shows. It holds the server address and nothing
/// that is a secret: the token stays inside the cubit and is in no state.
@immutable
class ConnectLinkState {
  const ConnectLinkState({
    required this.host,
    required this.address,
    required this.isPlainHttp,
    this.replacingHost,
    this.replacesCloud = false,
    this.phase = ConnectLinkPhase.ready,
    this.errorMessage,
    this.canRetry = true,
  });

  /// The part of the address a person recognises: the host, and the port
  /// when it is not the usual one.
  final String host;

  /// The whole address, as the link gave it.
  final String address;

  /// The address is `http`, so the connection is not encrypted.
  final bool isPlainHttp;

  /// The host of the server this phone is connected to now, which connecting
  /// replaces. Null when there is none.
  final String? replacingHost;

  /// True when the server in [replacingHost] is Crit Alarm Cloud. It is read
  /// in the same step as [replacingHost] and set with it, so the two always
  /// describe one server.
  final bool replacesCloud;

  final ConnectLinkPhase phase;

  /// The same line the manual connect screen shows for the failure.
  final String? errorMessage;

  /// False once the failure is one that asking again cannot change, such as
  /// a server that reports another address.
  final bool canRetry;

  bool get isConnecting => phase == ConnectLinkPhase.connecting;
  bool get isFailed => phase == ConnectLinkPhase.failed;
  bool get isConnected => phase == ConnectLinkPhase.connected;

  /// The server this phone is on now: its host and whether it is the
  /// cloud, always set together.
  ConnectLinkState withReplaced({
    required String host,
    required bool isCloud,
  }) => ConnectLinkState(
    host: this.host,
    address: address,
    isPlainHttp: isPlainHttp,
    replacingHost: host,
    replacesCloud: isCloud,
    phase: phase,
    errorMessage: errorMessage,
    canRetry: canRetry,
  );

  ConnectLinkState copyWith({
    ConnectLinkPhase? phase,
    String? errorMessage,
    bool? canRetry,
    bool clearErrorMessage = false,
  }) => ConnectLinkState(
    host: host,
    address: address,
    isPlainHttp: isPlainHttp,
    replacingHost: replacingHost,
    replacesCloud: replacesCloud,
    phase: phase ?? this.phase,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    canRetry: canRetry ?? this.canRetry,
  );

  @override
  bool operator ==(Object other) =>
      other is ConnectLinkState &&
      other.host == host &&
      other.address == address &&
      other.isPlainHttp == isPlainHttp &&
      other.replacingHost == replacingHost &&
      other.replacesCloud == replacesCloud &&
      other.phase == phase &&
      other.errorMessage == errorMessage &&
      other.canRetry == canRetry;

  @override
  int get hashCode => Object.hash(
    host,
    address,
    isPlainHttp,
    replacingHost,
    replacesCloud,
    phase,
    errorMessage,
    canRetry,
  );

  @override
  String toString() => 'ConnectLinkState($host, ${phase.name})';
}
