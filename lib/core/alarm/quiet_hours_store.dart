import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the quiet hours window is kept.
///
/// The four preference rows below are the truth. Every write also hands the
/// same four values to the native side, which copies them into the App Group
/// so the notification extension can read them: that extension runs in its own
/// process and cannot see the app's preferences.
final class QuietHoursStore {
  QuietHoursStore(this._prefs, {this.host});

  /// Plain preference keys. `shared_preferences` on iOS writes these into the
  /// standard user defaults with a `flutter.` prefix.
  static const String enabledKey = 'quiet_hours_enabled';
  static const String startKey = 'quiet_hours_start_minutes';
  static const String endKey = 'quiet_hours_end_minutes';
  static const String criticalRingsKey = 'quiet_hours_critical_rings';

  final SharedPreferences _prefs;

  /// The bridge that carries the window to the App Group. Null off iOS and in
  /// the tests that only care about the preference rows.
  final AlarmHost? host;

  /// Reads without waiting, because the ring decision happens on the push
  /// path and cannot afford a round trip. Anything unset falls back to
  /// [QuietHours.defaults].
  QuietHours read() => QuietHours(
    isEnabled: _prefs.getBool(enabledKey) ?? QuietHours.defaults.isEnabled,
    startMinutes: _prefs.getInt(startKey) ?? QuietHours.defaults.startMinutes,
    endMinutes: _prefs.getInt(endKey) ?? QuietHours.defaults.endMinutes,
    criticalRingsThrough:
        _prefs.getBool(criticalRingsKey) ??
        QuietHours.defaults.criticalRingsThrough,
  );

  Future<void> write(QuietHours window) async {
    await _prefs.setBool(enabledKey, window.isEnabled);
    await _prefs.setInt(startKey, window.startMinutes);
    await _prefs.setInt(endKey, window.endMinutes);
    await _prefs.setBool(criticalRingsKey, window.criticalRingsThrough);
    await host?.publishQuietHours(window);
  }
}
