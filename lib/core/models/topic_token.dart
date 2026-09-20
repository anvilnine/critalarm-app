import 'package:critalarm/core/models/date_time_converter.dart';
import 'package:flutter/foundation.dart';

final class TopicToken {
  const TopicToken({
    required this.token,
    required this.tokenId,
    required this.name,
  });

  /// The name arrives under two keys. `POST /v1/topics/{name}/tokens` calls it
  /// `name`; `POST /v1/topics` calls it `token_name` for the token it mints
  /// with the topic (api.md §3.1).
  factory TopicToken.fromJson(Map<String, dynamic> json) => TopicToken(
    token: json['token'] as String,
    tokenId: json['token_id'] as String,
    name: (json['name'] ?? json['token_name']) as String? ?? '',
  );
  final String token;
  final String tokenId;
  final String name;
  Map<String, dynamic> toJson() => {
    'token': token,
    'token_id': tokenId,
    'name': name,
  };
}

/// One of a topic's tokens, as the listing shows it.
///
/// The value is not here and cannot be. The server keeps a SHA-256 hash of
/// each token rather than the token, so `GET /v1/topics/{name}/tokens` answers
/// with ids, names and dates only (api.md §3.1). A value is shown once, when
/// the token is made, and never again.
///
/// The name is the thing you show. The value still exists on screen exactly
/// once, right after the token is made.
@immutable
final class TopicTokenInfo {
  const TopicTokenInfo({
    required this.tokenId,
    required this.name,
    this.createdAt,
  });

  factory TopicTokenInfo.fromJson(Map<String, dynamic> json) => TopicTokenInfo(
    tokenId: json['token_id'] as String,
    name: json['name'] as String? ?? '',
    createdAt: const NullableDateTimeConverter().fromJson(json['created_at']),
  );

  final String tokenId;
  final String name;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'token_id': tokenId,
    'name': name,
    if (createdAt != null)
      'created_at': createdAt!.millisecondsSinceEpoch ~/ 1000,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicTokenInfo &&
          runtimeType == other.runtimeType &&
          tokenId == other.tokenId &&
          name == other.name &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(tokenId, name, createdAt);
}
