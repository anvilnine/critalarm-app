final class TopicToken {
  const TopicToken({required this.token, required this.tokenId});
  factory TopicToken.fromJson(Map<String, dynamic> json) => TopicToken(
    token: json['token'] as String,
    tokenId: json['token_id'] as String,
  );
  final String token;
  final String tokenId;
  Map<String, dynamic> toJson() => {'token': token, 'token_id': tokenId};
}
