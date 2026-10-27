import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the answer's wire id under `setup_use`.
class SharedPrefsSetupUseStore implements SetupUseStore {
  const SharedPrefsSetupUseStore(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'setup_use';

  @override
  SetupUse? read() {
    try {
      return SetupUse.tryParse(_prefs.getString(key));
    } on Object {
      // A value of the wrong type, or a platform error: no answer.
      return null;
    }
  }

  @override
  Future<void> save(SetupUse use) async {
    await _prefs.setString(key, use.wire);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(key);
  }
}
