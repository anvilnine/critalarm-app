import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:flutter/foundation.dart';

enum CreateTopicStatus { initial, submitting, success, failure }

/// State for CreateTopicScreen.
/// Commitment made to Apple: [isCritical] MUST default to `false`.
@immutable
class CreateTopicState {
  const CreateTopicState({
    this.status = CreateTopicStatus.initial,
    this.name = 'prod-db',
    this.defaultPriority = PriorityLevel.defaultPriority,
    this.isCritical = false,
    this.createdToken,
    this.createdTopic,
    this.errorMessage,
  });

  final CreateTopicStatus status;
  final String name;
  final PriorityLevel defaultPriority;

  /// Critical delivery / Ring through silent mode. MUST DEFAULT TO FALSE.
  final bool isCritical;
  final String? createdToken;
  final Topic? createdTopic;
  final String? errorMessage;

  CreateTopicState copyWith({
    CreateTopicStatus? status,
    String? name,
    PriorityLevel? defaultPriority,
    bool? isCritical,
    String? createdToken,
    Topic? createdTopic,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateTopicState(
      status: status ?? this.status,
      name: name ?? this.name,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      isCritical: isCritical ?? this.isCritical,
      createdToken: createdToken ?? this.createdToken,
      createdTopic: createdTopic ?? this.createdTopic,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateTopicState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          name == other.name &&
          defaultPriority == other.defaultPriority &&
          isCritical == other.isCritical &&
          createdToken == other.createdToken &&
          createdTopic == other.createdTopic &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        status,
        name,
        defaultPriority,
        isCritical,
        createdToken,
        createdTopic,
        errorMessage,
      );
}
