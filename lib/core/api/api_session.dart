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

  /// What parts the four fields where the session is saved. The native
  /// readers split on it too, so no field may hold it.
  static const fieldSeparator = '|';

  /// The four fields in the order they are saved.
  List<String> get fields => [
    baseUri.toString(),
    relayUri.toString(),
    mode.wireValue,
    managementCredential,
  ];

  /// False when a field holds [fieldSeparator]. Saved, such a session could
  /// never be read back.
  bool get canBeSaved =>
      fields.every((field) => !field.contains(fieldSeparator));
}
