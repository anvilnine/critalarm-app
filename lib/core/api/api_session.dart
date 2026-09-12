/// Server mode reported by `GET /v1/info`.
enum ServerMode {
  selfhosted,
  relay,
  hosted;

  factory ServerMode.fromWireValue(String value) => switch (value) {
    'selfhosted' => ServerMode.selfhosted,
    'relay' => ServerMode.relay,
    'hosted' => ServerMode.hosted,
    _ => throw FormatException('Unsupported server mode: $value'),
  };

  String get wireValue => name;
}

/// Canonical endpoints and management credential for the active server.
final class ApiSession {
  const ApiSession({
    required this.baseUri,
    required this.relayUri,
    required this.mode,
    required this.managementCredential,
  });

  final Uri baseUri;
  final Uri relayUri;
  final ServerMode mode;
  final String managementCredential;
}
