import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';

/// How a [ConnectToServerUsecase] call ended.
sealed class ConnectOutcome {
  const ConnectOutcome();
}

/// The server answered, the session is set and the connection is saved.
final class Connected extends ConnectOutcome {
  const Connected(this.info);

  final ServerInfo info;
}

/// The server did not answer `/v1/info`.
final class ServerUnreachable extends ConnectOutcome {
  const ServerUnreachable(this.failure);

  final Failure failure;
}

/// The server runs a version this app does not speak.
final class ServerIncompatible extends ConnectOutcome {
  const ServerIncompatible(this.version);

  final String version;
}

/// A self-hosted server needs an admin token and none was given.
final class AdminTokenMissing extends ConnectOutcome {
  const AdminTokenMissing(this.info);

  final ServerInfo info;
}

/// The server answered but the connection could not be saved.
final class ConnectionNotSaved extends ConnectOutcome {
  const ConnectionNotSaved(this.failure);

  final Failure failure;
}

/// The connect threw on the way, which is a transport error.
final class ConnectTransportError extends ConnectOutcome {
  const ConnectTransportError(this.error);

  final Object error;
}

/// Connects the phone to a server: asks it who it is, checks the version,
/// sets up the session and saves the connection.
///
/// The setup connect step and a connect link both call this, so a server is
/// connected one way only. It does not touch the form, a draft, or what
/// comes after: the caller shows the result.
class ConnectToServerUsecase {
  const ConnectToServerUsecase(
    this._getServerInfo,
    this._establishSession,
    this._saveConnection, {
    this.cancelPendingConnect,
  });

  final GetServerInfoUsecase _getServerInfo;
  final EstablishApiSessionUsecase _establishSession;
  final SaveConnectionUsecase _saveConnection;

  /// Drops a Crit Alarm Cloud connect still waiting behind the user. A
  /// server picked by hand replaces it, and it must not save over this one.
  final Future<void> Function()? cancelPendingConnect;

  /// [serverUrl] and [adminToken] are trimmed here. The token is only
  /// handed to the session store and the saved connection, and it is in no
  /// outcome.
  Future<ConnectOutcome> call({
    required String serverUrl,
    required String adminToken,
  }) async {
    await cancelPendingConnect?.call();
    final token = adminToken.trim();
    final result = await _getServerInfo(Uri.parse(serverUrl.trim()));
    final failure = result.exceptionOrNull();
    if (failure != null) return ServerUnreachable(failure);
    final info = result.getOrThrow();

    if (!ServerInfoValidation.isSemverCompatible(info.version)) {
      return ServerIncompatible(info.version);
    }
    final mode = ServerMode.fromWireValue(info.mode);
    if (mode == ServerMode.selfhosted && token.isEmpty) {
      return AdminTokenMissing(info);
    }
    try {
      final session = await _establishSession(info, token);
      final saved = await _saveConnection(
        ServerConnection(
          serverUrl: info.baseUrl,
          adminToken: session.managementCredential,
        ),
      );
      final saveFailure = saved.exceptionOrNull();
      if (saveFailure != null) return ConnectionNotSaved(saveFailure);
      return Connected(info);
    } on Object catch (error) {
      return ConnectTransportError(error);
    }
  }
}
