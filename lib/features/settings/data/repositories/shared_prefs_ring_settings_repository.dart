import 'package:critalarm/features/settings/domain/entities/ring_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/ring_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two ring switches, kept in preferences.
///
/// The alarm rings with no Flutter engine running, so the native side reads
/// these keys straight out of the same preferences file. On iOS the plugin puts
/// `flutter.` in front of each key in the standard user defaults, and
/// `RingScreenRule` reads them there. On Android the file is
/// `FlutterSharedPreferences`, where the plugin puts `flutter.` in front of
/// each key (`RingSwitches` in the alarm code). Rename a key on both sides
/// or not at all: a key the native side cannot find reads as on.
class SharedPrefsRingSettingsRepository implements RingSettingsRepository {
  const SharedPrefsRingSettingsRepository(this._prefs);

  static const brightScreenKey = 'ring_bright_screen';
  static const vibrateKey = 'ring_vibrate';

  final SharedPreferences _prefs;

  @override
  RingSettings read() => RingSettings(
    brightScreen: _prefs.getBool(brightScreenKey) ?? true,
    vibrate: _prefs.getBool(vibrateKey) ?? true,
  );

  @override
  Future<void> setBrightScreen({required bool on}) async {
    await _prefs.setBool(brightScreenKey, on);
  }

  @override
  Future<void> setVibrate({required bool on}) async {
    await _prefs.setBool(vibrateKey, on);
  }
}
