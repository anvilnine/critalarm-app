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
/// Where the watch starts is the server's answer, never the phone's clock.
/// The first poll reads everything the topic holds and takes the newest
/// message as the baseline. On a topic that holds nothing the baseline is
/// "everything", so whatever arrives first counts. The baseline is saved
/// per topic, so a later watch on the same topic carries on from it.
///
/// A message after the baseline that is not a test alarm is the first
/// message. Then the flag in [FirstMessageStore] is set, [changes] emits
/// true once, and the polling ends.
class FirstMessageWatcher {
  FirstMessageWatcher({
    required this._store,
    required this._source,
    FirstMessageTimerFactory? timer,
  }) : _timer = timer ?? Timer.new;

  /// How long between two polls that went well.
  static const interval = Duration(seconds: 5);

  /// The longest wait between polls after the server could not be asked.
  static const maxInterval = Duration(minutes: 1);

  final FirstMessageStore _store;
  final FirstMessageSource _source;
  final FirstMessageTimerFactory _timer;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  String? _topic;
  Timer? _next;
  Duration _wait = interval;
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
      final saved = _store.cursorFor(topic);
      final page = await _source.read(
        topic,
        saved ?? FirstMessageSource.everything,
      );
      if (_isDisposed) return;
      if (saved != null && page.candidates.isNotEmpty) {
        // An alarm push may have said so first.
        if (_store.isReceived) return;
        await _store.markReceived();
        if (!_isDisposed) _changes.add(true);
        return;
      }
      // No first message yet. The next read starts after the newest
      // message seen: on the first poll that sets the baseline, and later
      // it steps past a test alarm so it is not read again. An empty topic
      // keeps "everything", so its very first message counts.
      final next = page.newestId ?? saved ?? FirstMessageSource.everything;
      if (next != saved) await _store.saveCursor(topic, next);
      _wait = interval;
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
}
