import 'package:critalarm/core/paywall/paywall_variant.dart';
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
    await PaywallAnalytics(gate).viewed(
      variant: PaywallVariant.values.first,
      source: 'reminder_morning_after',
    );
    expect(gate.events.single.$2?['source'], 'reminder_morning_after');
  });

  test('a view with no source says direct', () async {
    final gate = _RecordingGate();
    await PaywallAnalytics(gate).viewed(variant: PaywallVariant.values.first);
    expect(gate.events.single.$2?['source'], 'direct');
  });
}
