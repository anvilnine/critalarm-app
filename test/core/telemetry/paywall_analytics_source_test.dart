import 'package:critalarm/core/telemetry/paywall_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingGate extends NoopTelemetryGate {
  final events = <(String, Map<String, Object?>?)>[];

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => events.add((name, parameters));
}

void main() {
  test('a paywall view says where it was opened from', () async {
    final gate = _RecordingGate();
    await PaywallAnalytics(gate).viewed(source: 'reminder_morning_after');
    expect(gate.events.single.$2?['source'], 'reminder_morning_after');
  });

  test('a view with no source says direct', () async {
    final gate = _RecordingGate();
    await PaywallAnalytics(gate).viewed();
    expect(gate.events.single.$2?['source'], 'direct');
  });

  test('no paywall event carries a variant', () async {
    final gate = _RecordingGate();
    final analytics = PaywallAnalytics(gate);
    await analytics.viewed();
    await analytics.planSelected(plan: 'yearly');
    await analytics.purchaseStarted(plan: 'yearly');
    await analytics.purchaseCompleted(plan: 'yearly');
    await analytics.purchaseFailed(plan: 'yearly', reason: 'failed');
    expect(gate.events, hasLength(5));
    for (final (name, parameters) in gate.events) {
      expect(parameters?.containsKey('variant'), isFalse, reason: name);
    }
    expect(
      [for (final (name, _) in gate.events) name],
      [
        'paywall_viewed',
        'paywall_plan_selected',
        'paywall_purchase_started',
        'paywall_purchase_completed',
        'paywall_purchase_failed',
      ],
    );
  });
}
