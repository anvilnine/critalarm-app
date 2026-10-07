import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a developer's setup choices in the prefs, under two keys of their
/// own. Only a build with the developer tools is ever given this.
class SharedPrefsDeveloperOnboardingOverrides extends ChangeNotifier
    implements DeveloperOnboardingOverrides {
  SharedPrefsDeveloperOnboardingOverrides(this._prefs);

  final SharedPreferences _prefs;

  static const flowKey = 'dev.onboarding_flow';
  static const forcedKey = 'dev.onboarding_forced_unsatisfied';
  static const offerKey = 'dev.onboarding_offer';

  @override
  bool get isActive => true;

  @override
  String? get offerJson => _prefs.getString(offerKey);

  @override
  Future<void> setOfferJson(String? json) async {
    if (json == null) {
      await _prefs.remove(offerKey);
    } else {
      await _prefs.setString(offerKey, json);
    }
    notifyListeners();
  }

  @override
  DeveloperFlowChoice? get flowChoice =>
      DeveloperFlowChoice.decode(_prefs.getString(flowKey));

  @override
  Set<String> get forcedUnsatisfied => {
    ...?_prefs.getStringList(forcedKey),
  };

  @override
  Future<void> chooseFlow(DeveloperFlowChoice? choice) async {
    if (choice == null) {
      await _prefs.remove(flowKey);
    } else {
      await _prefs.setString(flowKey, choice.encode());
    }
    notifyListeners();
  }

  @override
  Future<void> forceUnsatisfied(String stepId, {required bool forced}) async {
    final next = forcedUnsatisfied;
    if (forced) {
      next.add(stepId);
    } else {
      next.remove(stepId);
    }
    if (next.isEmpty) {
      await _prefs.remove(forcedKey);
    } else {
      await _prefs.setStringList(forcedKey, next.toList());
    }
    notifyListeners();
  }
}

/// The overrides this build was compiled with. [enabled] is a compile-time
/// constant at the one call site, so a store build never holds a reference
/// to [SharedPrefsDeveloperOnboardingOverrides] and ignores whatever the
/// prefs contain.
DeveloperOnboardingOverrides developerOnboardingOverridesFor(
  SharedPreferences prefs, {
  bool enabled = buildHasOnboardingDeveloperTools,
}) => enabled
    ? SharedPrefsDeveloperOnboardingOverrides(prefs)
    : const NoDeveloperOnboardingOverrides();
