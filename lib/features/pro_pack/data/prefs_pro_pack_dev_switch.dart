import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Developer options switch for the Pro pack, kept in preferences.
///
/// Only registered when the app was built with
/// --dart-define=SKIP_PAYWALL=true. Store builds never see it.
class PrefsProPackDevSwitch extends ValueNotifier<bool>
    implements ProPackDevSwitch {
  PrefsProPackDevSwitch(this._prefs) : super(_prefs.getBool(_key) ?? false);

  static const _key = 'dev.pro_pack';

  final SharedPreferences _prefs;

  @override
  Future<void> setHeld({required bool isHeld}) async {
    value = isHeld;
    await _prefs.setBool(_key, isHeld);
  }
}
