import 'package:flutter/foundation.dart';

/// Stored server connection parameters.
@immutable
class ServerConnection {
  const ServerConnection({
    required this.serverUrl,
    required this.adminToken,
  });

  final String serverUrl;
  final String adminToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConnection &&
          runtimeType == other.runtimeType &&
          serverUrl == other.serverUrl &&
          adminToken == other.adminToken;

  @override
  int get hashCode => Object.hash(serverUrl, adminToken);
}
