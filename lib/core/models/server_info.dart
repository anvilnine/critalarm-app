import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

abstract final class ServerModes {
  static const selfhosted = 'selfhosted';
  static const relay = 'relay';
  static const hosted = 'hosted';

  static const List<String> validModes = [selfhosted, relay, hosted];
}

Object? _readStatedRelayContent(Map<dynamic, dynamic> json, String _) {
  final value = json['relay_content'];
  return value is String ? value : null;
}

/// Metadata describing the server instance and its operational mode.
@freezed
abstract class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    required String version,
    @JsonKey(name: 'base_url') required String baseUrl,
    @JsonKey(name: 'relay_url') required String relayUrl,
    @Default('critalarm') String name,
    @JsonKey(name: 'relay_content') @Default('none') String relayContent,

    /// `relay_content` as the server sent it, or null when the answer had
    /// no such field. [relayContent] falls back to `none` for an older
    /// server; this does not, so nothing is claimed about a server that
    /// did not say.
    @JsonKey(
      name: 'relay_content_stated',
      readValue: _readStatedRelayContent,
      includeToJson: false,
    )
    String? statedRelayContent,
    @Default(ServerModes.selfhosted) String mode,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}
