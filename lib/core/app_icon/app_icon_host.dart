import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks the platform which home screen icon is showing, and changes it.
///
/// iOS answers with its alternate icon sets (`AppDelegate.handleAppIconCall`),
/// Android with the launcher aliases in the manifest (`AppIconChannel.kt`).
/// Nothing answers on the web, which has no app icon to change, so [current]
/// comes back null there. That null is the capability: a platform that cannot
/// say which icon it shows does not get the picker.
final class AppIconHost {
  AppIconHost([this.channel = const MethodChannel(channelName)]);

  static const channelName = 'app.critalarm/app_icon';

  final MethodChannel channel;

  /// The icon on the home screen, or null when this platform cannot change it.
  Future<AppIcon?> current() async {
    try {
      final name = await channel.invokeMethod<String>('current');
      return AppIcon.fromPlatformName(name) ?? AppIcon.standard;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('CritAlarm: app_icon_current ${error.code}');
      return null;
    }
  }

  /// True when this platform can change the icon at all.
  Future<bool> canChangeAppIcon() async => await current() != null;

  /// Shows [icon] on the home screen. False when the platform refused.
  ///
  /// On iOS the system shows its own alert after every change. That is not
  /// something the app can turn off, so this only runs after a tap in the
  /// picker, or once when Pro has ended.
  Future<bool> set(AppIcon icon) async {
    try {
      await channel.invokeMethod<void>('set', {'icon': icon.platformName});
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('CritAlarm: app_icon_set ${error.code}');
      return false;
    }
  }
}
