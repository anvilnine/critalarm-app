import 'dart:async';

import 'package:critalarm/core/links/app_link.dart';

/// The connect link the user tapped, kept until a screen takes it.
///
/// Memory only. Nothing here writes to disk, builds a route, logs or reports,
/// and the app going away is the end of the link. One link at a time: a
/// second one replaces the first.
///
/// A link can arrive before anything listens, on a cold start, so it is held
/// as well as sent. A listener reads [pending] when it starts and [links]
/// after that, and calls [take] once it has shown the link.
final class ConnectLinkHolder {
  final _links = StreamController<ConnectLink>.broadcast();
  ConnectLink? _pending;

  /// Every link as it arrives.
  Stream<ConnectLink> get links => _links.stream;

  /// The link nobody took yet.
  ConnectLink? get pending => _pending;

  void offer(ConnectLink link) {
    _pending = link;
    if (!_links.isClosed) _links.add(link);
  }

  /// Hands the held link over, once.
  ConnectLink? take() {
    final link = _pending;
    _pending = null;
    return link;
  }

  /// Forgets the held link.
  void clear() => _pending = null;

  Future<void> dispose() async {
    _pending = null;
    await _links.close();
  }

  @override
  String toString() =>
      'ConnectLinkHolder(${_pending == null ? 'empty' : 'holding $_pending'})';
}
