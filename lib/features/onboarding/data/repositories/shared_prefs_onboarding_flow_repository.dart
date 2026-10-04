import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsOnboardingFlowRepository implements OnboardingFlowRepository {
  const SharedPrefsOnboardingFlowRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyFlowId = 'onboarding_flow_id';
  static const _keyFlowSteps = 'onboarding_flow_steps';
  static const _keyCompleted = 'onboarding_flow_completed';

  /// Written by versions that saved the step as an enum name. Only read once,
  /// to place a user who was halfway through, then removed.
  static const _keyLegacyStep = 'onboarding_step';

  @override
  OnboardingFlowProgress read() {
    final id = _prefs.getString(_keyFlowId);
    final steps = _prefs.getStringList(_keyFlowSteps);
    return OnboardingFlowProgress(
      pinned: id == null || steps == null
          ? null
          : OnboardingFlow(id: id, steps: steps),
      completed: {...?_prefs.getStringList(_keyCompleted)},
    );
  }

  @override
  Future<void> pin(OnboardingFlow flow) async {
    await _prefs.setString(_keyFlowId, flow.id);
    await _prefs.setStringList(_keyFlowSteps, flow.steps);
  }

  @override
  Future<void> saveCompleted(Set<String> stepIds) =>
      _prefs.setStringList(_keyCompleted, stepIds.toList());

  @override
  Future<void> clear() async {
    await _prefs.remove(_keyFlowId);
    await _prefs.remove(_keyFlowSteps);
    await _prefs.remove(_keyCompleted);
    await _prefs.remove(_keyLegacyStep);
  }

  @override
  String? readLegacyStep() => _prefs.getString(_keyLegacyStep);

  @override
  Future<void> removeLegacyStep() => _prefs.remove(_keyLegacyStep);
}
