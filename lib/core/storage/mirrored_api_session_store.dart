import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';

/// Writes the session the normal way and copies the two fields the iOS
/// Notification Service Extension needs into the keychain it can read.
///
/// The extension has ten seconds to turn a `relay_content: none` push into
/// real text (api.md §3.2, §5.1). It needs the canonical base URL and the
/// `dv_` management token to make that call, and it cannot ask Dart for them.
final class MirroredApiSessionStore implements ApiSessionStore {
  const MirroredApiSessionStore(this._inner, this._nse);

  final ApiSessionStore _inner;
  final NseCredentialStore _nse;

  @override
  Future<ApiSession?> read() => _inner.read();

  @override
  Future<void> write(ApiSession session) async {
    await _inner.write(session);
    await _nse.write(
      server: session.baseUri,
      token: session.managementCredential,
    );
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
    await _nse.clear();
  }
}
