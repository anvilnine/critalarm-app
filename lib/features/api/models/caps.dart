import 'package:freezed_annotation/freezed_annotation.dart';

part 'caps.freezed.dart';
part 'caps.g.dart';

/// Account caps as described in api.md §4.2.
@freezed
abstract class Caps with _$Caps {
  const factory Caps({
    required int devices,
    @JsonKey(name: 'critical_topics') required int criticalTopics,
    @JsonKey(name: 'p4_daily') required int p4Daily,
  }) = _Caps;

  factory Caps.fromJson(Map<String, dynamic> json) => _$CapsFromJson(json);
}
