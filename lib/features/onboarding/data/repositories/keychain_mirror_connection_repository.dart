import 'dart:async';

import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Saves the connection the normal way and copies it into the keychain the
/// iOS Notification Service Extension can read.
///
/// The extension has ten seconds to turn a `relay_content: none` push into
/// real text (api.md §3.2, §5.1). It needs the server URL and the token to
/// make that call, it runs in its own process, and it cannot ask Dart for
/// them. Shared preferences are out of reach from there; the keychain is not.
final class KeychainMirrorConnectionRepository implements ConnectionRepository {
  const KeychainMirrorConnectionRepository(
    this._inner,
    this._nse, {
    this._widgets,
  });

  final ConnectionRepository _inner;
  final NseCredentialStore _nse;

  /// Signing out blanks every home and lock screen widget. Optional so a test
  /// that only cares about the keychain can leave it out.
  final WidgetHost? _widgets;

  @override
  Future<AppResult<ServerConnection>> getConnection() => _inner.getConnection();

  /// The keychain write is a side effect, not part of saving. Waiting on it
  /// would put a platform channel round trip in the middle of onboarding, and
  /// a failed write only costs the extension its fetch: it falls back to the
  /// placeholder text and the alarm still rings.
  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection connection) async {
    final result = await _inner.saveConnection(connection);
    if (result.isSuccess()) {
      final server = Uri.tryParse(connection.serverUrl);
      if (server != null) {
        unawaited(_nse.write(server: server, token: connection.adminToken));
      }
    }
    return result;
  }

  @override
  Future<AppResult<Unit>> clearConnection() async {
    final result = await _inner.clearConnection();
    if (result.isSuccess()) {
      unawaited(_nse.clear());
      final widgets = _widgets;
      if (widgets != null) unawaited(widgets.clear());
    }
    return result;
  }
}
