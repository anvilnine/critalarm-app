import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The step ids a flow may list. They are saved on the phone and sent in a
/// remote flow, so a shipped id never changes its spelling.
abstract final class OnboardingStepId {
  static const welcome = 'welcome';
  static const howItRings = 'how_it_rings';
  static const connect = 'connect';
  static const permissions = 'permissions';
  static const firstTopic = 'first_topic';
  static const realRing = 'real_ring';
  static const hookUp = 'hook_up';
  static const widgets = 'widgets';

  /// The local test alarm, the last step of the order the app first shipped
  /// with.
  static const legacyTest = 'legacy_test';
}

/// The two setup screens the rest of the app opens on their own, after setup
/// is over. Each is pushed, and closes back to the screen that opened it.
abstract final class OnboardingEntryPoint {
  /// Connect a server, for a user who skipped it or disconnected.
  static const connectServer = '/onboarding/connect';

  /// The local test alarm.
  static const testAlarm = '/onboarding/test';
}

/// The order of the setup steps, as data: an id and a list of step ids.
///
/// A flow decides order and inclusion only. Copy and defaults stay in code.
@immutable
class OnboardingFlow {
  const OnboardingFlow({required this.id, required this.steps});

  final String id;
  final List<String> steps;

  bool contains(String stepId) => steps.contains(stepId);

  /// Reads `{"id": "...", "steps": ["...", ...]}` from a decoded map or from
  /// its JSON text. Null when the value is not that shape. Entries in `steps`
  /// that are not strings are left out.
  static OnboardingFlow? tryParse(Object? value) {
    var decoded = value;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException {
        return null;
      }
    }
    if (decoded is! Map) return null;
    final id = decoded['id'];
    final steps = decoded['steps'];
    if (id is! String || id.isEmpty || steps is! List) return null;
    return OnboardingFlow(id: id, steps: steps.whereType<String>().toList());
  }

  Map<String, Object> toJson() => {'id': id, 'steps': steps};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingFlow &&
          id == other.id &&
          listEquals(steps, other.steps);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(steps));

  @override
  String toString() => 'OnboardingFlow($id, $steps)';
}

/// The flows that ship inside the app.
abstract final class BundledOnboardingFlows {
  /// What a fresh install runs when no other source has a valid flow.
  static const defaultFlow = OnboardingFlow(
    id: '2026-10-a',
    steps: [
      OnboardingStepId.welcome,
      OnboardingStepId.howItRings,
      OnboardingStepId.connect,
      OnboardingStepId.permissions,
      OnboardingStepId.firstTopic,
      OnboardingStepId.realRing,
      OnboardingStepId.hookUp,
    ],
  );

  /// The order the app first shipped with, kept so the two can be compared.
  static const legacy = OnboardingFlow(
    id: 'legacy-1',
    steps: [
      OnboardingStepId.welcome,
      OnboardingStepId.howItRings,
      OnboardingStepId.permissions,
      OnboardingStepId.widgets,
      OnboardingStepId.connect,
      OnboardingStepId.legacyTest,
    ],
  );

  static const List<OnboardingFlow> all = [defaultFlow, legacy];
}
