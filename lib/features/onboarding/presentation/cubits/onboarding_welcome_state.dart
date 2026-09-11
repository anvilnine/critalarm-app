import 'package:flutter/foundation.dart';

@immutable
class OnboardingWelcomeState {
  const OnboardingWelcomeState({
    this.serverUrl = 'https://api.critalarm.app',
    this.isValidating = false,
    this.errorMessage,
    this.canNavigate = false,
  });

  final String serverUrl;
  final bool isValidating;
  final String? errorMessage;
  final bool canNavigate;

  OnboardingWelcomeState copyWith({
    String? serverUrl,
    bool? isValidating,
    String? errorMessage,
    bool? canNavigate,
    bool clearError = false,
  }) {
    return OnboardingWelcomeState(
      serverUrl: serverUrl ?? this.serverUrl,
      isValidating: isValidating ?? this.isValidating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canNavigate: canNavigate ?? this.canNavigate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingWelcomeState &&
          runtimeType == other.runtimeType &&
          serverUrl == other.serverUrl &&
          isValidating == other.isValidating &&
          errorMessage == other.errorMessage &&
          canNavigate == other.canNavigate;

  @override
  int get hashCode => Object.hash(
        serverUrl,
        isValidating,
        errorMessage,
        canNavigate,
      );
}
