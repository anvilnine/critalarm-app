import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Usecase to delete a topic by name.
class DeleteTopicUsecase implements UseCase<String, Unit> {
  const DeleteTopicUsecase(this._repository, [this._firstMessage]);

  final TopicRepository _repository;

  /// Null in tests that do not need it.
  final FirstMessageStore? _firstMessage;

  @override
  Future<AppResult<Unit>> call(String topicName) async {
    final result = await _repository.deleteTopic(topicName);
    // The point the first-message watch started from names a message of
    // the topic that is gone. A new topic with the same name starts fresh.
    // The "a first message arrived" flag is kept.
    if (result.getOrNull() != null) {
      await _firstMessage?.forgetTopic(topicName);
    }
    return result;
  }
}
