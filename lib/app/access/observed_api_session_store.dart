import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:flutter/foundation.dart';

/// An [ApiSessionStore] that also says which server mode the saved session
/// has, so feature access hears a connect without any caller telling it.
///
/// Every read, write and clear goes straight to the store it wraps.
/// [mode] is null until the first read or write, and whenever no session
/// is saved.
final class ObservedApiSessionStore implements ApiSessionStore {
  ObservedApiSessionStore(this._inner);

  final ApiSessionStore _inner;
  final _mode = ValueNotifier<ServerMode?>(null);

  /// The mode of the session last read or written through this store.
  ValueListenable<ServerMode?> get mode => _mode;

  @override
  Future<ApiSession?> read() async {
    final session = await _inner.read();
    _mode.value = session?.mode;
    return session;
  }

  @override
  Future<void> write(ApiSession session) async {
    await _inner.write(session);
    _mode.value = session.mode;
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
    _mode.value = null;
  }
}
