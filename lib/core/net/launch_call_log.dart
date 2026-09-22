import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';

/// Small in-memory history of network work performed while the app launched.
final class LaunchCallLog {
  LaunchCallLog({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxEntries = 50;
  final DateTime Function() _clock;
  final List<DebugLaunchCall> _entries = [];
  final Map<String, DateTime> _lastSuccessByName = {};

  List<DebugLaunchCall> get entries => List.unmodifiable(_entries);

  Map<String, DateTime> get lastSuccessByName =>
      Map.unmodifiable(_lastSuccessByName);

  void recordFailure({
    required String name,
    required int attempt,
    required Object error,
  }) {
    _append(
      DebugLaunchCall(
        name: name,
        at: _clock().toUtc(),
        attempt: attempt,
        error: error.toString(),
      ),
    );
  }

  void recordSuccess(String name, {DateTime? at}) {
    final time = (at ?? _clock()).toUtc();
    _lastSuccessByName[name] = time;
    _append(DebugLaunchCall(name: name, at: time));
  }

  List<DebugLaunchCall> recentFailures({int limit = 20}) => List.unmodifiable(
    _entries.reversed.where((entry) => !entry.succeeded).take(limit),
  );

  void _append(DebugLaunchCall entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }
}
