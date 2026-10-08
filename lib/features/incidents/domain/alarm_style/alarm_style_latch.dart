import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';

/// Holds the look of the alarm on screen still, for as long as that alarm
/// is on screen.
///
/// The look is decided once per incident, the first time the incident is
/// drawn ringing or acknowledged, and kept through every redraw after: the
/// tick of the ring time, the acknowledge, a ring that comes back. A plan
/// read that lands mid-ring, a purchase or a lapse changes nothing on a
/// screen someone is reaching for. Another incident taking the screen is
/// decided afresh.
///
/// It decides nothing itself: the caller's `decide` is asked, once, and
/// its answer is kept. Plain Dart with no clock and no storage, so it
/// lives and dies with the alarm screen that owns it.
class AlarmStyleLatch {
  String? _incidentId;
  AlarmStyleId? _style;

  /// The incident the kept look belongs to, or null when none is kept.
  String? get incidentId => _incidentId;

  /// The look for [incidentId]: the kept one when this incident already
  /// has one, else [decide]'s answer, which is then kept.
  ///
  /// An incident with no id cannot be told from the next one, so its look
  /// is asked for each time and nothing is kept.
  AlarmStyleId styleFor(
    String? incidentId, {
    required AlarmStyleId Function() decide,
  }) {
    if (incidentId == null || incidentId.isEmpty) {
      release();
      return decide();
    }
    final kept = _style;
    if (kept != null && incidentId == _incidentId) return kept;
    final style = decide();
    _incidentId = incidentId;
    _style = style;
    return style;
  }

  /// The alarm left the screen: nothing is kept.
  void release() {
    _incidentId = null;
    _style = null;
  }
}
