import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:flutter/foundation.dart';

enum CreateTopicStatus { initial, submitting, success, failure }

/// Which of the two steps the screen is on.
///
/// Nothing is created until [CreateTopicStep.token] submits, so backing out
/// of step 2 leaves no orphan topic behind.
enum CreateTopicStep { topic, token }

/// State for CreateTopicScreen.
/// Commitment made to Apple: [isCritical] MUST default to `false`.
@immutable
class CreateTopicState {
  const CreateTopicState({
    this.capReached,
    this.status = CreateTopicStatus.initial,
    this.step = CreateTopicStep.topic,
    this.name = '',
    this.tokenName = '',
    this.isCritical = false,
    this.createdToken,
    this.createdTopic,
    this.errorMessage,
    this.serverUrl = '',
    this.isFreeTier = true,
    this.criticalLimit = 2,
    this.criticalUsed = 0,
  });

  final CapReached? capReached;
  final CreateTopicStatus status;
  final CreateTopicStep step;
  final String name;

  /// What to call the token the server mints with the topic. Optional: an
  /// empty one leaves the server to call it `Token 1`.
  final String tokenName;

  /// Base URL of the server this app is connected to. The result card needs
  /// it to show the address the user points their script at; the token on its
  /// own is not enough to send anything.
  final String serverUrl;

  /// Critical delivery / Ring through silent mode. MUST DEFAULT TO FALSE.
  final bool isCritical;
  final String? createdToken;
  final Topic? createdTopic;
  final String? errorMessage;

  /// Whether the user is on the free tier.
  final bool isFreeTier;

  /// Limit of critical topics allowed on this plan (null for unlimited).
  final int? criticalLimit;

  /// Current number of critical topics the user has.
  final int criticalUsed;

  /// Remaining critical topics allowance, or null if unlimited.
  int? get criticalRemaining => criticalLimit == null
      ? null
      : (criticalLimit! - criticalUsed).clamp(0, criticalLimit!);

  CreateTopicState copyWith({
    CapReached? capReached,
    CreateTopicStatus? status,
    CreateTopicStep? step,
    String? name,
    String? tokenName,
    bool? isCritical,
    String? createdToken,
    Topic? createdTopic,
    String? errorMessage,
    String? serverUrl,
    bool? isFreeTier,
    int? criticalLimit,
    int? criticalUsed,
    bool clearError = false,
  }) {
    return CreateTopicState(
      capReached: clearError ? null : (capReached ?? this.capReached),
      status: status ?? this.status,
      step: step ?? this.step,
      name: name ?? this.name,
      tokenName: tokenName ?? this.tokenName,
      isCritical: isCritical ?? this.isCritical,
      createdToken: createdToken ?? this.createdToken,
      createdTopic: createdTopic ?? this.createdTopic,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      serverUrl: serverUrl ?? this.serverUrl,
      isFreeTier: isFreeTier ?? this.isFreeTier,
      criticalLimit: criticalLimit ?? this.criticalLimit,
      criticalUsed: criticalUsed ?? this.criticalUsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateTopicState &&
          runtimeType == other.runtimeType &&
          capReached == other.capReached &&
          status == other.status &&
          step == other.step &&
          name == other.name &&
          tokenName == other.tokenName &&
          isCritical == other.isCritical &&
          createdToken == other.createdToken &&
          createdTopic == other.createdTopic &&
          errorMessage == other.errorMessage &&
          serverUrl == other.serverUrl &&
          isFreeTier == other.isFreeTier &&
          criticalLimit == other.criticalLimit &&
          criticalUsed == other.criticalUsed;

  @override
  int get hashCode => Object.hash(
    capReached,
    status,
    step,
    name,
    tokenName,
    isCritical,
    createdToken,
    createdTopic,
    errorMessage,
    serverUrl,
    isFreeTier,
    criticalLimit,
    criticalUsed,
  );
}
