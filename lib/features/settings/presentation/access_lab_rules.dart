/// The pure rules of the Plans and features lab in Developer options: where
/// each feature shows, and what a row says. No widget here, so each rule is
/// tested as a plain function.
///
/// The lab never decides access. It writes the developer switches (a state
/// per holding and a server mode) and prints what `FeatureAccess` answers.
library;

import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';

/// The place in the app where a feature shows.
final class AccessLabJump {
  const AccessLabJump(this.label, this.location, {this.isTab = false});

  /// What the place is called, as a few words.
  final String label;

  /// The route to open.
  final String location;

  /// True for a place inside the tab shell. It is opened with `go`, which
  /// leaves the lab. Any other place is pushed over the lab, so back
  /// returns to it.
  final bool isTab;
}

/// Where each feature shows. A task that builds a screen for a new feature
/// adds its one line here, and takes the feature out of
/// [accessLabNotBuilt] if it was there.
const Map<AppFeature, AccessLabJump> accessLabJumps = {
  AppFeature.unlimitedCriticalTopics: AccessLabJump(
    'New topic',
    '/topics/new',
  ),
  AppFeature.longHistory: AccessLabJump('History', '/history', isTab: true),
  AppFeature.appIcons: AccessLabJump('App icon', '/app-icon'),
  AppFeature.widgets: AccessLabJump('Home widgets card', '/', isTab: true),
  AppFeature.ownSounds: AccessLabJump('Sound picker', '/sounds'),
  AppFeature.alarmScreenStyles: AccessLabJump(
    'Personalize, Look',
    '/settings/personalize',
  ),
  AppFeature.wakeUpChallenges: AccessLabJump(
    'Personalize, Challenge',
    '/settings/personalize',
  ),
  AppFeature.weeklyCheck: AccessLabJump(
    'Reliability',
    '/settings/reliability',
  ),
};

/// Pages that show several features at once, so they belong to no one row
/// of [accessLabJumps]: Personalize draws own sounds, widgets and app
/// icons, each with its lock. A task that adds a section there adds
/// nothing here.
const List<AccessLabJump> accessLabPages = [
  AccessLabJump('Personalize', '/settings/personalize'),
];

/// Features in the table that have no screen yet. Their row says so and
/// has no button.
const Set<AppFeature> accessLabNotBuilt = {};

/// The features the app has a name for on its own screens. The lab uses
/// the same words, so a row here and the strip or row it opens are called
/// one thing.
const Map<AppFeature, String> accessLabAppNames = {
  AppFeature.alarmScreenStyles: 'Look',
  AppFeature.wakeUpChallenges: 'Wake-up challenge',
};

/// A feature's name: the app's own words where it has them
/// ([accessLabAppNames]), else words made from its enum name, so a feature
/// added to the table gets a row with no edit here.
String accessLabFeatureName(AppFeature feature) =>
    accessLabAppNames[feature] ?? _words(feature.name);

String accessLabHoldingName(Holding holding) => _words(holding.name);

String _words(String camel) {
  final spaced = camel.replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => ' ${match[0]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// A holding state as one or two words.
String accessLabStateText(HoldingState state) => switch (state) {
  HoldingState.notHeld => 'not held',
  HoldingState.pending => 'purchase confirming',
  HoldingState.held => 'held',
  HoldingState.unknown => 'could not be read',
};

/// The label of one segment of a holding's control. Null is "follow the
/// real source".
String accessLabStateChoiceText(HoldingState? state) => switch (state) {
  null => 'Real',
  HoldingState.notHeld => 'None',
  HoldingState.pending => 'Pending',
  HoldingState.held => 'Held',
  HoldingState.unknown => 'Unread',
};

String accessLabServerChoiceText(ServerModeChoice choice) => switch (choice) {
  ServerModeChoice.real => 'Real',
  ServerModeChoice.cloud => 'Cloud',
  ServerModeChoice.ownServer => 'Own',
  ServerModeChoice.unknown => 'Unknown',
};

/// The mode of a saved session, as the server names it.
String accessLabServerModeText(ServerMode? mode) =>
    mode == null ? 'not known (no session)' : mode.name;

/// What `FeatureAccess.decide` answered, as a few words.
String accessLabDecisionText(FeatureDecision decision) => switch (decision) {
  FeatureOpen() => 'Open',
  FeatureLocked(:final offer) => 'Locked, sells ${accessLabHoldingName(offer)}',
  FeatureConfirming(:final holding) =>
    'Open, confirming ${accessLabHoldingName(holding)}',
  FeatureUnread(:final holding) =>
    'Open, ${accessLabHoldingName(holding)} unread',
  FeatureNotOffered() => 'Not offered on this server, sells nothing',
};

/// Who unlocks a feature, read from its row in the table.
String accessLabRuleText(FeatureRule? rule) {
  if (rule == null || rule.unlockedBy.isEmpty) return 'No row: open to all';
  final holdings = rule.unlockedBy.map(accessLabHoldingName).join(' or ');
  final own = switch (rule.onOwnServer) {
    OwnServerRule.open => 'or own server',
    OwnServerRule.sameAsCloud => 'own server too',
    OwnServerRule.notOffered => 'not offered on own server',
  };
  // Named only where there is a choice to make.
  final sells = rule.unlockedBy.length > 1
      ? ', sells ${accessLabHoldingName(rule.offered)}'
      : '';
  return 'Needs $holdings, $own$sells';
}

/// Where a feature's row goes, as the second half of its detail line.
String accessLabJumpText(AppFeature feature) {
  final jump = accessLabJumps[feature];
  if (jump != null) return 'Goes to ${jump.label}';
  return accessLabNotBuilt.contains(feature)
      ? 'Not built yet'
      : 'No jump target registered';
}

String _forcedPart(Holding holding, HoldingState state) =>
    '${accessLabHoldingName(holding)} ${accessLabStateText(state)}';

/// The line Developer options shows at its top while anything is forced.
/// Null when nothing is.
String? accessLabForcedLine({
  required Map<Holding, HoldingState?> forced,
  required ServerModeChoice serverMode,
  bool holdsPlanRead = false,
}) {
  final parts = <String>[
    for (final holding in Holding.values)
      if (forced[holding] != null) _forcedPart(holding, forced[holding]!),
    if (serverMode != ServerModeChoice.real)
      'server ${accessLabServerChoiceText(serverMode).toLowerCase()}',
    if (holdsPlanRead) 'plan read held open',
  ];
  if (parts.isEmpty) return null;
  return 'Forced, not real: ${parts.join(', ')}';
}

/// The line under a holding's control: what the app acts on, and what the
/// source says underneath.
String accessLabHoldingLine({
  required HoldingState seen,
  required HoldingState real,
}) =>
    'App sees ${accessLabStateText(seen)}. '
    'Real source says ${accessLabStateText(real)}.';

/// One line under the presets for the preset that needs saying, or null.
String? accessLabPresetNote(AccessPreset? preset) => switch (preset) {
  AccessPreset.planReading =>
    'The plan read never finishes. Restart the app to see locks wait for '
        'it. Real releases it.',
  _ => null,
};
