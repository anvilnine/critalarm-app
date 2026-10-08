/// The pure rules of the Developer options screen: which sections a build
/// shows, in what order, and what a row says as its value. No widget and no
/// string lookup here, so each rule is tested as a plain function.
library;

/// The groups of Developer options, in the order they are listed.
enum DeveloperSection {
  /// The switches that hold a plan or a pack with no purchase.
  plans,

  /// What the paywalls open.
  paywalls,

  /// The setup flow, its replays and its switches.
  setup,

  /// Pages that only open: galleries, labs and debug views. Always last.
  tools,
}

/// The sections one build shows, top to bottom.
///
/// [hasPlanSwitches] is a build that skips the store. [hasSetupTools] is a
/// developer build on a phone where setup runs. Paywalls and tools are in
/// every build that reaches the screen, and tools close the list.
List<DeveloperSection> developerSectionsFor({
  required bool hasPlanSwitches,
  required bool hasSetupTools,
}) => [
  if (hasPlanSwitches) DeveloperSection.plans,
  DeveloperSection.paywalls,
  if (hasSetupTools) DeveloperSection.setup,
  DeveloperSection.tools,
];

/// What one product's paywall opens, as a few words: the intro, then the
/// layout. A null is a choice left to the remote value and reads [remote].
/// With both left to it the answer is [remote] once.
String paywallPairText({
  required String? intro,
  required String? layout,
  required String remote,
}) {
  if (intro == null && layout == null) return remote;
  return '${intro ?? remote}, ${layout ?? remote}';
}

/// The value of the flow row: [none] with no override, [custom] for a typed
/// list, and the flow's own id for a bundled one.
String developerFlowValueText({
  required String? bundledId,
  required bool isCustom,
  required String none,
  required String custom,
}) {
  if (isCustom) return custom;
  return bundledId ?? none;
}
