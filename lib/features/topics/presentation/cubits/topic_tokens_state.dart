import 'package:critalarm/core/models/topic_token.dart';
import 'package:flutter/foundation.dart';

enum TopicTokensStatus { initial, loading, ready, failure }

/// What the Tokens section on a topic knows.
@immutable
class TopicTokensState {
  const TopicTokensState({
    this.status = TopicTokensStatus.initial,
    this.tokens = const <TopicTokenInfo>[],
    this.isWorking = false,
    this.newToken,
    this.newTokenName,
    this.errorMessage,
  });

  final TopicTokensStatus status;

  /// Ids, names and dates, oldest first. No values: the server holds a hash of
  /// each token and has nothing to show twice.
  final List<TopicTokenInfo> tokens;

  /// A token is being made, renamed or revoked right now.
  final bool isWorking;

  /// The one-time value of a token just made. Shown until it is dismissed,
  /// and never fetched again, because nothing can fetch it.
  final String? newToken;

  /// What that token is called, shown above its value.
  final String? newTokenName;

  final String? errorMessage;

  bool get isReady => status == TopicTokensStatus.ready;

  /// The server refuses to take a topic's last token, so the app does not
  /// offer to.
  bool get canRevoke => tokens.length > 1;

  TopicTokensState copyWith({
    TopicTokensStatus? status,
    List<TopicTokenInfo>? tokens,
    bool? isWorking,
    String? newToken,
    String? newTokenName,
    String? errorMessage,
    bool clearNewToken = false,
    bool clearError = false,
  }) {
    return TopicTokensState(
      status: status ?? this.status,
      tokens: tokens ?? this.tokens,
      isWorking: isWorking ?? this.isWorking,
      newToken: clearNewToken ? null : (newToken ?? this.newToken),
      newTokenName: clearNewToken ? null : (newTokenName ?? this.newTokenName),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicTokensState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          isWorking == other.isWorking &&
          newToken == other.newToken &&
          newTokenName == other.newTokenName &&
          errorMessage == other.errorMessage &&
          listEquals(tokens, other.tokens);

  @override
  int get hashCode => Object.hash(
    status,
    isWorking,
    newToken,
    newTokenName,
    errorMessage,
    Object.hashAll(tokens),
  );
}
