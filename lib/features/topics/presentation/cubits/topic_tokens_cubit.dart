import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Tokens section on a topic: what it has, making one more, revoking one.
///
/// Its own cubit rather than more fields on the topic screen's, because it
/// reads a different route and nothing else on that screen depends on it.
class TopicTokensCubit extends Cubit<TopicTokensState> {
  TopicTokensCubit(this._getTokens, this._createToken, this._revokeToken)
    : super(const TopicTokensState());

  final GetTopicTokensUsecase _getTokens;
  final CreateTopicTokenUsecase _createToken;
  final RevokeTopicTokenUsecase _revokeToken;

  late String _topicName;

  /// Which topic this section is for, so a retry does not need it passed
  /// in again.
  String get topicName => _topicName;

  Future<void> load(String topicName) async {
    _topicName = topicName;
    if (isClosed) return;
    emit(state.copyWith(status: TopicTokensStatus.loading, clearError: true));

    final result = await _getTokens(topicName);
    if (isClosed) return;

    result.fold(
      (tokens) => emit(
        state.copyWith(
          status: TopicTokensStatus.ready,
          tokens: tokens,
          clearError: true,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          status: TopicTokensStatus.failure,
          errorMessage: failureMessage(failure),
        ),
      ),
    );
  }

  /// Makes one more token and keeps its value on screen.
  ///
  /// The value is only in this answer. Nothing can ask for it again, so it
  /// stays in the state until the person dismisses it.
  Future<void> createToken() async {
    if (isClosed || state.isWorking) return;
    emit(
      state.copyWith(isWorking: true, clearError: true, clearNewToken: true),
    );

    final result = await _createToken(_topicName);
    if (isClosed) return;

    result.fold(
      (made) => emit(
        state.copyWith(
          isWorking: false,
          status: TopicTokensStatus.ready,
          tokens: [...state.tokens, TopicTokenInfo(tokenId: made.tokenId)],
          newToken: made.token,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          isWorking: false,
          errorMessage: failureMessage(failure),
        ),
      ),
    );
  }

  /// Revokes one token, taking it off the list before asking.
  ///
  /// A server that refuses puts it back where it was. The last token cannot be
  /// revoked, which the button already knows, but a second device could have
  /// deleted the others in the meantime, so the answer is still handled.
  Future<void> revoke(String tokenId) async {
    if (isClosed || state.isWorking) return;

    final at = state.tokens.indexWhere((t) => t.tokenId == tokenId);
    if (at < 0) return;
    final removed = state.tokens[at];

    emit(
      state.copyWith(
        isWorking: true,
        tokens: [...state.tokens]..removeAt(at),
        clearError: true,
        clearNewToken: true,
      ),
    );

    final result = await _revokeToken(
      RevokeTopicTokenParams(topicName: _topicName, tokenId: tokenId),
    );
    if (isClosed) return;

    result.fold(
      (_) => emit(state.copyWith(isWorking: false)),
      (failure) => emit(
        state.copyWith(
          isWorking: false,
          tokens: [...state.tokens]
            ..insert(at.clamp(0, state.tokens.length), removed),
          errorMessage: failureMessage(failure),
        ),
      ),
    );
  }

  /// Puts the one-time value away. It is gone for good after this.
  void dismissNewToken() {
    if (isClosed) return;
    emit(state.copyWith(clearNewToken: true));
  }
}
