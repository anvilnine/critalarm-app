import 'dart:async';
import 'dart:convert';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/core/widgets/widget_snapshot.dart';

/// Keeps the widget snapshot in step with the app's own lists.
///
/// Every change to the shared topic or incident list writes a new snapshot,
/// a moment later so a burst of changes is one write. Nothing is written until
/// both lists have loaded once, because a half-loaded snapshot would show
/// "all quiet" over a ringing incident. A failed refresh keeps its list, so a
/// list that loaded once keeps being written.
class WidgetSync {
  WidgetSync({
    required this._topics,
    required this._incidents,
    required this._host,
    required this._isConnected,
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 500),
  }) : _now = now ?? DateTime.now;

  final TopicsCubit _topics;
  final IncidentsCubit _incidents;
  final WidgetHost _host;
  final Future<bool> Function() _isConnected;
  final DateTime Function() _now;
  final Duration debounce;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _timer;
  bool _topicsLoaded = false;
  bool _incidentsLoaded = false;

  /// The last snapshot written, without `updated_at`, so a write that only
  /// moves the clock is skipped. It carries the host's clear count, so a
  /// sign-out in between always leads to a fresh write.
  String? _lastWritten;

  void start() {
    _subscriptions
      ..add(_topics.stream.listen((_) => _schedule()))
      ..add(_incidents.stream.listen((_) => _schedule()));
    _schedule();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Lets the next snapshot be written even if it matches the last one. The
  /// native side can store a snapshot on its own (a 401 in the notification
  /// extension, a widget refresh, or a lock screen action), so the app calls
  /// this on resume. It writes nothing by itself: the lists here are still
  /// the ones from before the resume, and writing them could cover a newer
  /// native change. The refresh that follows the resume does the write.
  void forget() {
    _lastWritten = null;
  }

  void _schedule() {
    _topicsLoaded |= _topics.state.isReady;
    _incidentsLoaded |= _incidents.state.isReady;
    if (!_topicsLoaded || !_incidentsLoaded) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_write()));
  }

  Future<void> _write() async {
    final snapshot = buildWidgetSnapshot(
      topics: _topics.state.topics,
      incidents: _incidents.state.incidents,
      connected: await _isConnected(),
      now: _now(),
    );
    final json = snapshot.toJson();
    final key =
        '${_host.clears}:${jsonEncode({...json}..remove('updated_at'))}';
    if (key == _lastWritten) return;
    _lastWritten = key;
    await _host.write(jsonEncode(json));
  }
}
