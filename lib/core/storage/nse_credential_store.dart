import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The server URL and management token, kept where the iOS Notification
/// Service Extension can read them.
///
/// The extension runs in its own process with its own container, so shared
/// preferences are out of reach. It reads the keychain instead, through the
/// access group both targets carry. `NseCredentials.swift` is the other half.
///
/// Off iOS every call is a no-op: nothing answers the channel, so the platform
/// raises [MissingPluginException] and this swallows it.
final class NseCredentialStore {
  const NseCredentialStore([this.channel = const MethodChannel(channelName)]);

  static const channelName = 'app.critalarm/nse_credentials';

  final MethodChannel channel;

  Future<void> write({required Uri server, required String token}) => _invoke(
    'write',
    {'server': server.toString(), 'token': token},
  );

  Future<void> clear() => _invoke('clear');

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
      // Whether the extension has credentials is the difference between it
      // fetching the real text and showing the placeholder, and nothing else
      // reports it. The token is not logged.
      if (kDebugMode) debugPrint('CritAlarm: nse_credentials_$method ok');
    } on MissingPluginException {
      if (kDebugMode) debugPrint('CritAlarm: nse_credentials_$method skipped');
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('CritAlarm: nse_credentials_$method failed ${error.code}');
      }
    }
  }
}
