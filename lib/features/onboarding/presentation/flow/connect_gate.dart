import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';

/// What the setup shell puts on a step while a connect runs behind the user.
enum ConnectGate {
  /// The step shows as it is.
  none,

  /// The step shows, with one quiet line saying the connect is on its way.
  quiet,

  /// The step needs the server and the connect has not landed: the waiting
  /// face and one line stand in for it until it does.
  waiting,

  /// The connect gave up, or the step needs a server and there is none.
  /// The reason and one button back to the connect step stand in for the
  /// step.
  failed,
}

/// Decides what the shell shows on the step at [path] for [state].
///
/// [hasConnection] is whether a server connection is saved. A step that
/// needs the server never opens without one: with nothing pending and
/// nothing saved it shows the failed gate, which is what a relaunch after a
/// failure comes back to.
///
/// The connect step is never covered, because it is where a failure sends
/// the user. A replay from Settings connects to nothing, so it is never
/// covered either.
ConnectGate connectGateFor({
  required BackgroundConnectState state,
  required String path,
  required bool isReplay,
  required bool hasConnection,
}) {
  if (isReplay) return ConnectGate.none;
  final entry = OnboardingStepRegistry.entryForPath(path);
  if (entry == null || entry.id == OnboardingStepId.connect) {
    return ConnectGate.none;
  }
  if (state.isFailed) return ConnectGate.failed;
  final needsServer = entry.requires.contains(OnboardingStepId.connect);
  if (state.isPending) {
    return needsServer ? ConnectGate.waiting : ConnectGate.quiet;
  }
  if (needsServer && !state.isConnected && !hasConnection) {
    return ConnectGate.failed;
  }
  return ConnectGate.none;
}
