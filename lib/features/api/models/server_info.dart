import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

/// Server info returned by `GET /v1/info`.
@freezed
abstract class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    required String name,
    required String version,
    @JsonKey(name: 'base_url') required String baseUrl,
    @JsonKey(name: 'relay_url') required String relayUrl,
    @JsonKey(name: 'relay_content') required String relayContent,
    required String mode,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}
