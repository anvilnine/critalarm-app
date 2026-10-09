import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/backup/backup_host.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';

/// Makes an install that was restored onto another phone start as a phone
/// the relay has never seen.
///
/// An iPhone backup carries the app's preferences to the next phone, and an
/// encrypted computer backup or a phone to phone transfer carries the
/// Keychain as well. Left alone, the new phone would talk to the relay with
/// the old phone's device id and device token, and trust flags the old
/// phone wrote on a sure answer about its plan.
///
/// When [BackupHost.installMarker] says the install moved, this runs once,
/// at launch, before anything reads the identity:
///
/// 1. `AccountData.forget()`: the acknowledgements still waiting, the poll
///    cursors, the recent searches, the challenge choices and flags, the
///    alarm looks and their note, the own sounds lock flag, the own photo.
///    Nothing else here drops account data.
/// 2. The saved session and connection, when the token in them is this
///    phone's device token (every server but one of the person's own). A
///    server of the person's own keeps its connection: that token was typed
///    in by the person and names no phone.
/// 3. The device identity: the device id and the device token. The synced
///    account item stays, the same as on a fresh install on the same Apple
///    ID, so the new phone can join the person's account.
/// 4. The record of the push token last sent, so the launch registration
///    sends this phone's own, and the old phone's Live Activity tokens.
///
/// Then it asks for a connect to the server the old phone was on, which is
/// the path a fresh install takes: a new device id, a new registration, a
/// new device token.
///
/// The marker is settled only when every drop went through. A launch that
/// died halfway, or could not drop something, answers moved again next
/// time and runs the whole list again. Every step is safe to run twice.
///
/// Taste stays: theme, the chosen built-in sound, quiet hours. So does
/// everything Android would have lost with it, which is the difference
/// between the two platforms: Android restores nothing.
class MovedPhoneReset {
  MovedPhoneReset({
    required this._host,
    required this._forgetAccountData,
    required this._sessions,
    required this._connections,
    required this._devices,
    required this._forgetSentPushToken,
    required this._reconnect,
  });

  final BackupHost _host;

  /// `AccountData.forget()`.
  final Future<void> Function() _forgetAccountData;
  final ApiSessionStore _sessions;
  final ConnectionRepository _connections;
  final DeviceIdentityStore _devices;

  /// Drops what the launch registration compares the push token against,
  /// and every push token of the old phone that is still on this one.
  final Future<void> Function() _forgetSentPushToken;

  /// Starts a connect to a server address, the way setup does. Answers
  /// once the request is saved, not once it lands.
  final Future<void> Function(String serverUrl) _reconnect;

  /// True when this launch found a moved install and dropped what came
  /// with it. Never throws: a launch must not fail on this.
  Future<bool> run() async {
    final InstallMarkerVerdict verdict;
    try {
      verdict = await _host.installMarker();
    } on Object catch (_) {
      return false;
    }
    if (verdict != InstallMarkerVerdict.moved) return false;

    var dropped = true;
    Future<void> step(Future<void> Function() drop) async {
      try {
        await drop();
      } on Object catch (_) {
        dropped = false;
      }
    }

    await step(_forgetAccountData);

    // Read before anything is cleared: where to connect again afterwards.
    ApiSession? session;
    String? serverUrl;
    await step(() async => session = await _sessions.read());
    await step(() async {
      serverUrl = (await _connections.getConnection()).getOrNull()?.serverUrl;
    });
    // How the token was made, not a plan: only a server of the person's own
    // takes a token the person typed. With no session to say, the token is
    // treated as this phone's.
    final ownServer =
        session?.mode == ServerMode.selfhosted; // access-ok: connect
    if (!ownServer) {
      await step(_sessions.clear);
      await step(() async {
        final cleared = await _connections.clearConnection();
        if (cleared.isError()) dropped = false;
      });
    }

    await step(_devices.clear);
    await step(_forgetSentPushToken);
    // The new id is settled now, so the registration the launch starts and
    // the connect below both register the same one.
    await step(_devices.readOrCreate);

    if (!dropped) return true;
    await _host.settleInstallMarker();

    final url = serverUrl ?? session?.baseUri.toString();
    if (!ownServer && url != null && url.isNotEmpty) {
      try {
        await _reconnect(url);
      } on Object catch (_) {
        // The person connects from Home, as after any disconnect.
      }
    }
    return true;
  }
}
