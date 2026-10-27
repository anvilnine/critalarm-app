import 'package:critalarm/core/account/account_identity_changes.dart';

/// Which account the phone's archive of incidents and messages belongs to
/// right now, and the write guard that keeps a late write out of the next
/// account's rows.
///
/// A row carries a scope: a hash of the saved server address and the account
/// id (`heldScopeFor`). A read asks for the current scope and gets only that
/// scope's rows. Signing out keeps the rows, so signing back in to the same
/// account brings the history back, and no other account is ever handed
/// them.
///
/// [current] is null for a store that has one account only (a unit test, a
/// capture). Every row then sits under [single].
class ArchiveScope {
  ArchiveScope({
    this._current,
    AccountIdentityChanges? changes,
  }) : _changes = changes ?? appAccountIdentityChanges {
    _changes.addListener(_onIdentityChanged);
  }

  /// The scope of every row in a store that was given no [current].
  static const single = 'single';

  final Future<String?> Function()? _current;
  final AccountIdentityChanges _changes;

  /// Counts sign-ins, sign-outs, account switches and deletes. A write
  /// remembers the number it started under and is dropped when it moved.
  int _generation = 0;

  void _onIdentityChanged() => _generation++;

  /// Stops listening. The store calls it when it closes.
  void dispose() => _changes.removeListener(_onIdentityChanged);

  /// The scope the phone is on now, or null when it is on none (no server is
  /// saved) or the answer cannot be read. A null scope reads as an empty
  /// archive and stores nothing.
  Future<String?> current() async {
    final read = _current;
    if (read == null) return single;
    try {
      return await read();
    } on Object catch (_) {
      return null;
    }
  }

  /// Starts a write. Call it before the request or the event the data came
  /// from, so the write knows which account that was.
  ArchiveTicket begin() => ArchiveTicket._(this, _generation, current());
}

/// One write's claim on the archive.
///
/// It settles to the scope to write under, or to null when the write must not
/// be stored: no scope was known when it started, the identity changed since,
/// or the phone is on another scope now. An alarm is rung before any of this
/// runs, so a dropped write costs a row in the archive and nothing else. The
/// next sync fetches the incident again for the account it belongs to.
class ArchiveTicket {
  ArchiveTicket._(this._scope, this._generation, this._started);

  final ArchiveScope _scope;
  final int _generation;
  final Future<String?> _started;

  Future<String?> settle() async {
    final startedAs = await _started;
    if (startedAs == null || _scope._generation != _generation) return null;
    return startedAs == await _scope.current() ? startedAs : null;
  }
}
