import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// The one analytics event of the cancel question. It carries the wire name of
/// the chip and nothing the person typed. Nothing leaves while the person has
/// analytics switched off: that is the gate's rule, so this class asks no one.
abstract final class CancelReasonEvents {
  static const cancelReason = 'cancel_reason';
}

final class CancelReasonAnalytics {
  const CancelReasonAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> reason(CancelReason reason) => _gate.logEvent(
    CancelReasonEvents.cancelReason,
    {'reason': reason.wire},
  );
}
