import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the Pro/Free choice made in the developer section of Settings.
///
/// Only registered when the app was built with
/// --dart-define=SKIP_PAYWALL=true. Store builds never see it.
class DevProSwitch extends ValueNotifier<bool> {
  DevProSwitch(this._prefs) : super(_prefs.getBool(_key) ?? false);

  static const _key = 'dev.pro_mode';

  final SharedPreferences _prefs;

  /// Puts the app into Pro or Free and remembers the choice across launches.
  Future<void> setPro({required bool isPro}) async {
    value = isPro;
    await _prefs.setBool(_key, isPro);
  }
}
