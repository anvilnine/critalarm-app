import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// Event names for a connect link. Neither one carries the server address
/// or the token: only that a link was opened and how it ended.
abstract final class ConnectLinkEvents {
  static const opened = 'connect_link_opened';
  static const ended = 'connect_link_ended';
}

/// How a connect link ended, for `connect_link_ended`.
enum ConnectLinkEnd {
  /// The person connected.
  connected('connected'),

  /// The connect failed and the person left.
  failed('failed'),

  /// The person said not now, or swiped the sheet away.
  notNow('not_now'),

  /// An alarm took the screen before the person answered.
  interrupted('interrupted');

  const ConnectLinkEnd(this.wire);

  final String wire;
}

/// Thin wrapper so callers name an event instead of building a params map.
/// Nothing is sent unless the user turned analytics on in Settings.
final class ConnectLinkAnalytics {
  const ConnectLinkAnalytics(this._gate);

  final TelemetryGate _gate;

  Future<void> opened() => _gate.logEvent(ConnectLinkEvents.opened);

  Future<void> ended(ConnectLinkEnd end) =>
      _gate.logEvent(ConnectLinkEvents.ended, {'result': end.wire});
}
