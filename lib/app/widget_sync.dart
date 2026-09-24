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
  /// moves the clock is skipped.
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
    final withoutClock = jsonEncode({...json}..remove('updated_at'));
    if (withoutClock == _lastWritten) return;
    _lastWritten = withoutClock;
    await _host.write(jsonEncode(json));
  }
}
