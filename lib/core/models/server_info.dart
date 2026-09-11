import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

abstract final class ServerModes {
  static const selfhosted = 'selfhosted';
  static const relay = 'relay';
  static const hosted = 'hosted';
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
    @Default(ServerModes.selfhosted) String mode,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}
