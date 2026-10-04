import 'dart:convert';

import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';

/// The flow Remote Config holds under `onboarding_flow`.
///
/// Reads whatever the gate has activated already. It never fetches and never
/// waits, so a value still on its way answers null and the next source is
/// asked. A value that arrives later applies to the next fresh install.
///
/// Only the shape is checked here. The step ids and their order go through
/// the same validator as every other source.
class RemoteOnboardingFlowSource implements OnboardingFlowSource {
  const RemoteOnboardingFlowSource(this._gate);

  final TelemetryGate _gate;

  /// The id becomes an analytics parameter, so it stays short and plain.
  static final _idPattern = RegExp(r'^[A-Za-z0-9._-]{1,40}$');

  @override
  OnboardingFlow? current() {
    final String raw;
    try {
      raw = _gate.onboardingFlowJson.trim();
    } on Object catch (_) {
      return null;
    }
    if (raw.isEmpty) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final id = decoded['id'];
    final steps = decoded['steps'];
    if (id is! String || !_idPattern.hasMatch(id)) return null;
    if (steps is! List || !steps.every((step) => step is String)) return null;

    // Rebuilt from the two fields, so nothing else in the value is read.
    return OnboardingFlow.tryParse({'id': id, 'steps': steps});
  }
}
