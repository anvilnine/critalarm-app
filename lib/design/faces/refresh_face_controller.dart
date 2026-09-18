import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/foundation.dart';

/// Where the refresh face is in its sequence.
enum RefreshFacePhase {
  /// No refresh. The face is whatever the screen gave it.
  idle,

  /// A finger is pulling the list down, or the list is springing back.
  pulling,

  /// The refresh is running.
  working,

  /// The refresh worked.
  success,

  /// The refresh failed.
  failed,

  /// Going back to the face the screen gave it.
  settling,
}

/// Runs the pull-to-refresh face: about to work, working, success or failed,
/// back to normal. Holds no widgets, so it tests without a screen.
class RefreshFaceController extends ChangeNotifier {
  /// [now] and [delay] are only swapped out by tests.
  RefreshFaceController({
    required this.onRefresh,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  /// How far the list has to be pulled, in logical pixels, to refresh.
  static const double pullDistance = 80;

  /// The refresh. True when it worked. The screen may swap it on rebuild.
  Future<bool> Function() onRefresh;

  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  bool _disposed = false;

  /// Where the sequence is.
  RefreshFacePhase get phase => _phase;
  RefreshFacePhase _phase = RefreshFacePhase.idle;

  /// How far the pull is toward [pullDistance], 0 to 1.
  double get progress => _progress;
  double _progress = 0;

  /// True while the pull is far enough that letting go will refresh.
  bool get isArmed => _phase == RefreshFacePhase.pulling && _progress >= 1;

  /// The list is pulled [distance] pixels past its top. Ignored while a
  /// refresh is running or finishing.
  void pull(double distance) {
    if (_phase != RefreshFacePhase.idle && _phase != RefreshFacePhase.pulling) {
      return;
    }
    if (distance <= 0) {
      if (_phase == RefreshFacePhase.idle) return;
      _phase = RefreshFacePhase.idle;
      _progress = 0;
      notifyListeners();
      return;
    }
    _phase = RefreshFacePhase.pulling;
    _progress = (distance / pullDistance).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// The finger let go. Refreshes when the pull reached [pullDistance],
  /// otherwise leaves the spring back of the list to relax the face.
  Future<void> release() async {
    if (_phase != RefreshFacePhase.pulling || _progress < 1) return;

    _set(RefreshFacePhase.working);
    final started = _now();
    bool worked;
    try {
      worked = await onRefresh();
    } on Object {
      worked = false;
    }
    if (_disposed) return;

    final elapsed = _now().difference(started);
    if (elapsed < AppDurations.faceWorkingMin) {
      await _delay(AppDurations.faceWorkingMin - elapsed);
      if (_disposed) return;
    }

    _set(worked ? RefreshFacePhase.success : RefreshFacePhase.failed);
    await _delay(
      worked ? AppDurations.faceSuccessHold : AppDurations.faceFailedHold,
    );
    if (_disposed) return;

    _set(RefreshFacePhase.settling);
    await _delay(AppDurations.base);
    if (_disposed) return;

    _progress = 0;
    _set(RefreshFacePhase.idle);
  }

  void _set(RefreshFacePhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
