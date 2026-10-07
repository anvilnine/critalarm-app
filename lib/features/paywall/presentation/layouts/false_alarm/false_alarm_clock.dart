import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/foundation.dart';

/// The frame's clock, moved on by a tap that skips the joke.
///
/// The layout hands it to everything it draws, so the joke, the offer's
/// entrance and the previews all read the same second. Before the frame
/// has handed over its own clock it reads zero. When nothing may move it
/// reads [restAt], from the first frame.
class FalseAlarmClock extends ChangeNotifier implements PaywallClock {
  FalseAlarmClock({required this.restAt});

  /// The second it holds when nothing may move.
  final double restAt;

  PaywallClock? _base;
  double _shift = 0;

  /// True when nothing may move. The layout sets it on every build, with
  /// the same rule the frame uses.
  bool still = false;

  /// Follows the frame's clock from here on.
  void follow(PaywallClock clock) {
    if (identical(clock, _base)) return;
    _base?.removeListener(notifyListeners);
    _base = clock..addListener(notifyListeners);
  }

  @override
  double get value => still ? restAt : (_base?.value ?? 0) + _shift;

  @override
  bool get isStill => still;

  /// Jumps to the reveal when the joke is still playing. Returns whether
  /// anything changed.
  bool skip() {
    if (still) return false;
    final now = value;
    final to = FalseAlarmTimeline.skip(now);
    if (to == now) return false;
    _shift += to - now;
    notifyListeners();
    return true;
  }

  @override
  void restart() {
    _shift = 0;
    _base?.restart();
  }

  @override
  void dispose() {
    _base?.removeListener(notifyListeners);
    super.dispose();
  }
}
