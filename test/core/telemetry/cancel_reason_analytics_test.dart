import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/core/telemetry/cancel_reason_analytics.dart';
import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late _MockAnalytics analytics;
  late FirebaseTelemetryGate gate;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.setAnalyticsCollectionEnabled(any()),
    ).thenAnswer((_) async {});
    when(() => analytics.resetAnalyticsData()).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});
    gate = FirebaseTelemetryGate(analytics: analytics);
  });

  test('sends nothing while analytics is off', () async {
    await CancelReasonAnalytics(gate).reason(CancelReason.price);
    verifyNever(
      () => analytics.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    );
  });

  test(
    'sends cancel_reason with the wire name only while analytics is on',
    () async {
      await gate.setAnalyticsEnabled(true);
      await CancelReasonAnalytics(gate).reason(CancelReason.selfhost);
      verify(
        () => analytics.logEvent(
          name: 'cancel_reason',
          parameters: {'reason': 'selfhost'},
        ),
      ).called(1);
    },
  );
}
