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
    this.phase = ConnectLinkPhase.ready,
    this.errorMessage,
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

  final ConnectLinkPhase phase;

  /// The same line the manual connect screen shows for the failure.
  final String? errorMessage;

  bool get isConnecting => phase == ConnectLinkPhase.connecting;
  bool get isFailed => phase == ConnectLinkPhase.failed;
  bool get isConnected => phase == ConnectLinkPhase.connected;

  ConnectLinkState copyWith({
    String? replacingHost,
    ConnectLinkPhase? phase,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ConnectLinkState(
    host: host,
    address: address,
    isPlainHttp: isPlainHttp,
    replacingHost: replacingHost ?? this.replacingHost,
    phase: phase ?? this.phase,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  bool operator ==(Object other) =>
      other is ConnectLinkState &&
      other.host == host &&
      other.address == address &&
      other.isPlainHttp == isPlainHttp &&
      other.replacingHost == replacingHost &&
      other.phase == phase &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(
    host,
    address,
    isPlainHttp,
    replacingHost,
    phase,
    errorMessage,
  );

  @override
  String toString() => 'ConnectLinkState($host, ${phase.name})';
}
