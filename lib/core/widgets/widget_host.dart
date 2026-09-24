import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hands the widget snapshot to the platform, which stores it where the
/// widgets read it and asks the OS to redraw them.
///
/// iOS keeps it in the app group, Android in the `critalarm_widgets`
/// preferences. Off those two nothing answers the channel, so the platform
/// raises [MissingPluginException] and this swallows it, the same as
/// `NseCredentialStore`.
final class WidgetHost {
  const WidgetHost([this.channel = const MethodChannel(channelName)]);

  static const channelName = 'app.critalarm/widgets';

  final MethodChannel channel;

  /// Stores [json], a whole snapshot, and redraws every widget.
  Future<void> write(String json) => _invoke('write', {'json': json});

  /// Stores the signed-out snapshot and redraws every widget.
  Future<void> clear() => _invoke('clear');

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      if (kDebugMode) debugPrint('CritAlarm: widgets_$method skipped');
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('CritAlarm: widgets_$method failed ${error.code}');
      }
    }
  }
}
