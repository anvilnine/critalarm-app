import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';

/// The answer the user gave on the `use` step. Kept on the phone only.
/// Nothing about it reaches the server.
///
/// It is a preference and not account data, so setup completing and a
/// sign-out leave it alone.
abstract interface class SetupUseStore {
  /// The saved answer, or null when none is saved or the stored value is not
  /// one this build knows.
  SetupUse? read();

  Future<void> save(SetupUse use);

  Future<void> clear();
}

/// The answer a replay of setup picked, held in memory for that run.
///
/// A replay saves nothing, yet the replayed screens after the `use` step
/// still show what was picked. Gone when the app closes.
class SetupUseReplay {
  SetupUse? pick;

  // ignore: use_setters_to_change_properties, a replay says it sets a pick.
  void set(SetupUse use) => pick = use;

  void clear() => pick = null;
}

/// The answer a screen should draw for.
///
/// In a replay it is the replay's pick, and the saved answer while the replay
/// has not picked yet. Outside a replay it is the saved answer. Null when
/// there is none, which every reader treats as [SetupUse.other].
///
/// Reads only. A replay never calls [SetupUseStore.save].
SetupUse? setupUseFor({
  required bool isReplay,
  required SetupUseStore store,
  required SetupUseReplay replay,
}) => (isReplay ? replay.pick : null) ?? store.read();
