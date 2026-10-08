import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:flutter/foundation.dart';

/// Which server the developer override says this phone is on.
enum ServerModeChoice {
  /// Follow the saved session. The only value a store build ever has.
  real,

  /// Act as Crit Alarm Cloud.
  cloud,

  /// Act as a server of the user's own.
  ownServer,

  /// Act as if the server is not known.
  unknown,
}

/// What a developer set: a state per holding, and a server mode. The
/// override reads it, and Developer options writes it.
abstract interface class AccessSwitches implements Listenable {
  /// The state [holding] is forced to, or null to follow its source.
  HoldingState? forcedState(Holding holding);

  ServerModeChoice get serverMode;
}

/// Lets a developer build put the app in any plan state with no purchase.
///
/// It overrides at the source level and nowhere else: the state of a
/// holding (`OverriddenHoldingSource`) and the server mode
/// (`OverriddenServerMode`). `Holdings` and `FeatureAccess` read those the
/// way they read the real ones, so there is still one path from a purchase
/// to a decision. No feature is ever forced open or locked.
///
/// Which override a build gets is settled when the app is compiled.
/// [appAccessOverride] picks [DevAccessOverride] only when
/// `buildSkipsPaywall` is true, a compile-time constant. A store build is
/// compiled with [NoAccessOverride], which has nowhere to keep a switch:
/// calling [watch] on it does nothing, and it forces no state.
abstract interface class AccessOverride {
  /// Fires when a forced value may have changed, or null when this build
  /// has no override.
  Listenable? get listenable;

  /// The state [holding] is forced to, or null to follow its source.
  HoldingState? forcedState(Holding holding);

  ServerModeChoice get serverMode;

  /// The mode to act on, given the [real] one from the saved session.
  ServerMode? serverModeOver(ServerMode? real);

  /// Starts reporting [switches]. Does nothing in a build with no override.
  void watch(AccessSwitches switches);
}

/// The override a store build is compiled with. No storage, no listener,
/// and every answer is the real one.
class NoAccessOverride implements AccessOverride {
  const NoAccessOverride();

  @override
  Listenable? get listenable => null;

  @override
  HoldingState? forcedState(Holding holding) => null;

  @override
  ServerModeChoice get serverMode => ServerModeChoice.real;

  @override
  ServerMode? serverModeOver(ServerMode? real) => real;

  @override
  void watch(AccessSwitches switches) {}
}

/// The override a `--dart-define=SKIP_PAYWALL=true` build is compiled with.
class DevAccessOverride implements AccessOverride {
  AccessSwitches? _switches;

  @override
  Listenable? get listenable => _switches;

  @override
  HoldingState? forcedState(Holding holding) => _switches?.forcedState(holding);

  @override
  ServerModeChoice get serverMode =>
      _switches?.serverMode ?? ServerModeChoice.real;

  @override
  ServerMode? serverModeOver(ServerMode? real) => switch (serverMode) {
    ServerModeChoice.real => real,
    ServerModeChoice.cloud => ServerMode.hosted,
    ServerModeChoice.ownServer => ServerMode.selfhosted,
    ServerModeChoice.unknown => null,
  };

  @override
  void watch(AccessSwitches switches) => _switches = switches;
}

/// The override this build was compiled with. Constant condition, so a
/// store build never holds a reference to [DevAccessOverride].
final AccessOverride appAccessOverride = buildSkipsPaywall
    ? DevAccessOverride()
    : const NoAccessOverride();

/// A [HoldingSource] with the developer override in front of it.
///
/// Every source `Holdings` reads is wrapped in one of these, so the
/// override is the same seam for every holding, old and new. With nothing
/// forced, and always in a store build, each answer is the real source's.
final class OverriddenHoldingSource implements HoldingSource {
  OverriddenHoldingSource(this._real, {AccessOverride? override})
    : _override = override ?? appAccessOverride;

  final HoldingSource _real;
  final AccessOverride _override;

  @override
  Holding get holding => _real.holding;

  @override
  HoldingState get state => _override.forcedState(holding) ?? _real.state;

  /// What the source itself says, whatever is forced.
  HoldingState get realState => _real.state;

  /// One object for the life of the wrapper, so a listener that was added
  /// can be removed.
  @override
  late final Listenable changes = () {
    final forced = _override.listenable;
    return forced == null
        ? _real.changes
        : Listenable.merge([_real.changes, forced]);
  }();

  @override
  Future<void> get ready => _real.ready;
}

/// The server mode feature access acts on: the saved session's, with the
/// developer override in front of it.
final class OverriddenServerMode {
  OverriddenServerMode(this._real, {AccessOverride? override})
    : _override = override ?? appAccessOverride;

  final ValueListenable<ServerMode?> _real;
  final AccessOverride _override;

  ServerMode? get value => _override.serverModeOver(_real.value);

  /// What the saved session says, whatever is forced.
  ServerMode? get realValue => _real.value;

  /// Fires when [value] may have changed.
  late final Listenable changes = () {
    final forced = _override.listenable;
    return forced == null ? _real : Listenable.merge([_real, forced]);
  }();
}
