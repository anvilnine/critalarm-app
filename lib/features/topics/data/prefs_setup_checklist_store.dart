import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SetupChecklistStore] on the phone, under `setup_checklist_seeded`,
/// `setup_checklist_done`, `setup_checklist_set_up_here` and
/// `home_widgets_card_seen`.
class PrefsSetupChecklistStore implements SetupChecklistStore {
  const PrefsSetupChecklistStore(this._prefs);

  final SharedPreferences _prefs;

  static const seededKey = 'setup_checklist_seeded';
  static const doneKey = 'setup_checklist_done';
  static const widgetsCardSeenKey = 'home_widgets_card_seen';
  static const setUpHereKey = 'setup_checklist_set_up_here';

  @override
  bool get wasSetUpHere => _prefs.getBool(setUpHereKey) ?? false;

  @override
  Future<void> markSetUpHere() => _prefs.setBool(setUpHereKey, true);

  @override
  bool get isSeeded => _prefs.getBool(seededKey) ?? false;

  @override
  Future<void> markSeeded() => _prefs.setBool(seededKey, true);

  @override
  bool get isDone => _prefs.getBool(doneKey) ?? false;

  @override
  Future<void> markDone() => _prefs.setBool(doneKey, true);

  @override
  bool get isWidgetsCardSeen => _prefs.getBool(widgetsCardSeenKey) ?? false;

  @override
  Future<void> markWidgetsCardSeen() =>
      _prefs.setBool(widgetsCardSeenKey, true);
}
