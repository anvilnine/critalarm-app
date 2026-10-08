import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One tap in the Plans and features lab: a state for every holding.
///
/// A preset only sets holdings. The server mode is its own control, so
/// "Free" can be looked at on Crit Alarm Cloud and on a server of the
/// user's own. [real] is the exception: it releases every override, the
/// server mode with them.
enum AccessPreset {
  free('Free', {
    Holding.hosted: HoldingState.notHeld,
    Holding.pro: HoldingState.notHeld,
  }),
  hosted('Hosted', {
    Holding.hosted: HoldingState.held,
    Holding.pro: HoldingState.notHeld,
  }),
  pro('Pro', {
    Holding.hosted: HoldingState.notHeld,
    Holding.pro: HoldingState.held,
  }),
  hostedAndPro('Hosted and Pro', {
    Holding.hosted: HoldingState.held,
    Holding.pro: HoldingState.held,
  }),
  purchaseConfirming('Purchase confirming', {
    Holding.hosted: HoldingState.notHeld,
    Holding.pro: HoldingState.pending,
  }),
  planUnreadable('Plan could not be read', {
    Holding.hosted: HoldingState.unknown,
    Holding.pro: HoldingState.unknown,
  }),
  real('Real', {});

  const AccessPreset(this.label, this.holdings);

  final String label;

  /// The state each holding is forced to. A holding left out follows its
  /// source.
  final Map<Holding, HoldingState> holdings;
}

/// What a developer set in Developer options, kept in preferences so it is
/// still there after a restart.
///
/// The one store behind every developer plan switch: the Plans and
/// features lab, and the two older toggles, which are "force held" and
/// "release" on the same values ([forcedHeld]).
///
/// Only registered when the app was built with
/// --dart-define=SKIP_PAYWALL=true. Store builds never see it.
class DevAccessSwitches extends ChangeNotifier implements AccessSwitches {
  DevAccessSwitches(this._prefs) {
    for (final holding in Holding.values) {
      final state = _readState(holding);
      if (state != null) _forced[holding] = state;
    }
    _serverMode = _readServerMode();
  }

  static const serverModeKey = 'dev.access.server';

  static String holdingKey(Holding holding) => 'dev.access.${holding.name}';

  /// Where the two toggles kept a yes or no before this class. A phone
  /// that still has one reads it as "forced held", once, until the next
  /// write for that holding.
  static String legacyKey(Holding holding) => switch (holding) {
    Holding.hosted => 'dev.pro_mode',
    Holding.pro => 'dev.pro_pack',
  };

  final SharedPreferences _prefs;
  final _forced = <Holding, HoldingState>{};
  final _heldViews = <Holding, ValueListenable<bool>>{};
  late ServerModeChoice _serverMode;

  HoldingState? _readState(Holding holding) {
    final stored = _prefs.getString(holdingKey(holding));
    if (stored != null) {
      for (final state in HoldingState.values) {
        if (state.name == stored) return state;
      }
      return null;
    }
    return (_prefs.getBool(legacyKey(holding)) ?? false)
        ? HoldingState.held
        : null;
  }

  ServerModeChoice _readServerMode() {
    final stored = _prefs.getString(serverModeKey);
    for (final choice in ServerModeChoice.values) {
      if (choice.name == stored) return choice;
    }
    return ServerModeChoice.real;
  }

  @override
  HoldingState? forcedState(Holding holding) => _forced[holding];

  @override
  ServerModeChoice get serverMode => _serverMode;

  /// Whether anything is forced, so what the app shows is not what the
  /// real sources say.
  bool get isAnyOn =>
      _forced.isNotEmpty || _serverMode != ServerModeChoice.real;

  /// The preset whose holdings are exactly what is forced now, or null.
  /// [AccessPreset.real] also needs the server mode released.
  AccessPreset? get preset {
    for (final preset in AccessPreset.values) {
      if (!mapEquals(preset.holdings, _forced)) continue;
      if (preset == AccessPreset.real && isAnyOn) continue;
      return preset;
    }
    return null;
  }

  /// True while [holding] is forced to held. What the two older toggles
  /// show, and what the older override classes listen to.
  ValueListenable<bool> forcedHeld(Holding holding) =>
      _heldViews.putIfAbsent(holding, () => _ForcedHeld(this, holding));

  /// Forces [holding] to [state], or releases it when [state] is null.
  Future<void> force(Holding holding, HoldingState? state) async {
    _set(holding, state);
    notifyListeners();
    await _save(holding);
  }

  Future<void> setServerMode(ServerModeChoice choice) async {
    if (choice == _serverMode) return;
    _serverMode = choice;
    notifyListeners();
    await _saveServerMode();
  }

  /// Sets every holding to what [preset] says, in one change.
  Future<void> apply(AccessPreset preset) async {
    for (final holding in Holding.values) {
      _set(holding, preset.holdings[holding]);
    }
    if (preset == AccessPreset.real) _serverMode = ServerModeChoice.real;
    notifyListeners();
    for (final holding in Holding.values) {
      await _save(holding);
    }
    await _saveServerMode();
  }

  /// Hands everything back to the real sources.
  Future<void> releaseAll() => apply(AccessPreset.real);

  void _set(Holding holding, HoldingState? state) {
    if (state == null) {
      _forced.remove(holding);
    } else {
      _forced[holding] = state;
    }
  }

  Future<void> _save(Holding holding) async {
    final state = _forced[holding];
    await _prefs.remove(legacyKey(holding));
    if (state == null) {
      await _prefs.remove(holdingKey(holding));
    } else {
      await _prefs.setString(holdingKey(holding), state.name);
    }
  }

  Future<void> _saveServerMode() async {
    if (_serverMode == ServerModeChoice.real) {
      await _prefs.remove(serverModeKey);
    } else {
      await _prefs.setString(serverModeKey, _serverMode.name);
    }
  }
}

/// "Is this holding forced to held", as a yes or no that can be listened
/// to. It tells its listeners on every change of the switches, with or
/// without a change of its own value.
final class _ForcedHeld implements ValueListenable<bool> {
  const _ForcedHeld(this._switches, this._holding);

  final DevAccessSwitches _switches;
  final Holding _holding;

  @override
  bool get value => _switches.forcedState(_holding) == HoldingState.held;

  @override
  void addListener(VoidCallback listener) => _switches.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _switches.removeListener(listener);
}
