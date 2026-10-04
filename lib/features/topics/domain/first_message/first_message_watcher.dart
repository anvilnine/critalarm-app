import 'dart:async';

import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';

typedef FirstMessageTimerFactory =
    Timer Function(Duration duration, void Function() onFire);

/// Watches one topic for the first message the user's own tool sends.
///
/// It polls while something on screen is waiting and at no other time: the
/// owner calls [start] when its screen opens, [pause] and [resume] as the
/// app leaves and returns to the front, and [dispose] when the screen goes.
/// There is no background work.
///
/// The watch starts after setup's own test message, so that one never
/// counts. With no test sent it starts at the second [start] was called.
/// The starting point is saved per topic, so a later watch on the same
/// topic carries on from it.
///
/// When a message lands the flag in [FirstMessageStore] is set, [changes]
/// emits true once, and the polling ends.
class FirstMessageWatcher {
  FirstMessageWatcher({
    required this._store,
    required this._source,
    DateTime Function()? now,
    FirstMessageTimerFactory? timer,
  }) : _now = now ?? DateTime.now,
       _timer = timer ?? Timer.new;

  /// How long between two polls that went well.
  static const interval = Duration(seconds: 5);

  /// The longest wait between polls after the server could not be asked.
  static const maxInterval = Duration(minutes: 1);

  /// How many times the test message is asked for before the watch starts
  /// from its own clock instead.
  static const baselineTries = 3;

  final FirstMessageStore _store;
  final FirstMessageSource _source;
  final DateTime Function() _now;
  final FirstMessageTimerFactory _timer;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  String? _topic;
  DateTime? _startedAt;
  Timer? _next;
  Duration _wait = interval;
  int _baselineFailures = 0;
  bool _isPaused = false;
  bool _isPolling = false;
  bool _isDisposed = false;

  /// True once a first message has landed, on this watch or an earlier one.
  bool get isReceived => _store.isReceived;

  /// Emits true once, when the first message lands while this is watching.
  Stream<bool> get changes => _changes.stream;

  /// Begins watching [topic] and makes the first poll. Does nothing when a
  /// first message was already received.
  Future<void> start(String topic) async {
    if (_isDisposed || _store.isReceived) return;
    _topic = topic;
    _startedAt ??= _now();
    await _poll();
  }

  /// A message is known to have landed without a poll: its alarm reached
  /// this phone. Sets the flag, tells the listener and ends the polling.
  /// Does nothing when a first message was already received.
  Future<void> arrived() async {
    if (_isDisposed || _store.isReceived) return;
    _next?.cancel();
    await _store.markReceived();
    if (!_isDisposed) _changes.add(true);
  }

  /// The app left the front. No poll runs until [resume].
  void pause() {
    _isPaused = true;
    _next?.cancel();
  }

  /// The app is back at the front. Polls at once.
  void resume() {
    _isPaused = false;
    if (_topic == null) return;
    unawaited(_poll());
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _next?.cancel();
    await _changes.close();
  }

  bool get _isStopped => _isDisposed || _isPaused || _store.isReceived;

  Future<void> _poll() async {
    final topic = _topic;
    if (topic == null || _isStopped || _isPolling) return;
    _next?.cancel();
    _isPolling = true;
    try {
      final cursor = await _cursor(topic);
      if (_isDisposed) return;
      if (cursor == null) {
        _slowDown();
      } else {
        final ids = await _source.newerThan(topic, cursor);
        if (_isDisposed) return;
        if (ids.isNotEmpty) {
          // An alarm push may have said so first.
          if (_store.isReceived) return;
          await _store.markReceived();
          if (!_isDisposed) _changes.add(true);
          return;
        }
        _wait = interval;
      }
    } on Exception {
      // Nothing changes on screen. The next poll asks again, later.
      _slowDown();
    } finally {
      _isPolling = false;
    }
    if (_isStopped) return;
    _next = _timer(_wait, () => unawaited(_poll()));
  }

  void _slowDown() {
    final doubled = _wait * 2;
    _wait = doubled > maxInterval ? maxInterval : doubled;
  }

  /// The saved starting point, or a new one. Null while setup's test
  /// message cannot be read and it is too early to give up on it.
  Future<String?> _cursor(String topic) async {
    final saved = _store.cursorFor(topic);
    if (saved != null) return saved;

    String? cursor;
    try {
      cursor = (await _source.testBaseline()).messageId;
    } on Exception {
      _baselineFailures++;
      if (_baselineFailures < baselineTries) return null;
    }
    cursor ??= '${_startedAt!.millisecondsSinceEpoch ~/ 1000}';
    await _store.saveCursor(topic, cursor);
    return cursor;
  }
}
