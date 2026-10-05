import 'dart:async';

/// How long Ring me for real waits before the server is asked to send, so
/// the user has time to lock the phone or leave the app.
///
/// The one place to change it. Zero turns the wait off: the tap sends at
/// once, with no countdown and no terminal.
const Duration realRingSendDelay = Duration(seconds: 5);

typedef SendCountdownTicker =
    Timer Function(Duration period, void Function(Timer timer) onTick);

/// The wait between the tap on Ring me for real and the call to the server.
///
/// It only counts and says when to send. It never talks to the server
/// itself: [onSend] does, once per started countdown at most.
///
/// - [start] begins the count. A second call while it runs does nothing.
/// - [cancel] stops it and sends nothing.
/// - [leftFront] is the app going to the background. A timer is not
///   promised to run there, and the user leaving is the sign they are
///   ready, so the send happens at once.
///
/// With a [delay] of zero or less, [start] sends at once.
class SendCountdown {
  SendCountdown({
    required this.onChanged,
    required this.onSend,
    this.delay = realRingSendDelay,
    SendCountdownTicker? ticker,
  }) : _ticker = ticker ?? Timer.periodic;

  /// Told the whole seconds left on every change, and null once the count
  /// is over, whether it sent or was cancelled.
  final void Function(int? secondsLeft) onChanged;

  /// Asks the server. Called when the count reaches zero, or when the app
  /// leaves the front while it runs.
  final void Function() onSend;

  final Duration delay;
  final SendCountdownTicker _ticker;

  Timer? _timer;
  int? _secondsLeft;
  bool _isDisposed = false;

  /// The whole seconds left, or null when nothing is counting.
  int? get secondsLeft => _secondsLeft;

  bool get isRunning => _secondsLeft != null;

  /// The tap. Returns false when a count was already running.
  bool start() {
    if (_isDisposed || isRunning) return false;
    final seconds = delay.inSeconds;
    if (seconds <= 0) {
      onSend();
      return true;
    }
    _set(seconds);
    _timer = _ticker(const Duration(seconds: 1), (_) => _tick());
    return true;
  }

  void _tick() {
    final left = _secondsLeft;
    if (left == null) return;
    if (left <= 1) {
      _finish(send: true);
    } else {
      _set(left - 1);
    }
  }

  /// Cancel. Back to where the tap was, with nothing sent.
  void cancel() {
    if (!isRunning) return;
    _finish(send: false);
  }

  /// The app left the front. A running count ends now and sends.
  void leftFront() {
    if (!isRunning) return;
    _finish(send: true);
  }

  void _finish({required bool send}) {
    _timer?.cancel();
    _timer = null;
    _set(null);
    if (send && !_isDisposed) onSend();
  }

  void _set(int? seconds) {
    _secondsLeft = seconds;
    if (!_isDisposed) onChanged(seconds);
  }

  /// Stops everything. Nothing is sent and nothing is reported afterwards.
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _secondsLeft = null;
  }
}
