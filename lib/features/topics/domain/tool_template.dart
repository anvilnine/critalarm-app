import 'package:flutter/foundation.dart';

/// The tool a user is setting up to send to their first topic.
///
/// A chip on the create-topic screen picks one. The [id] is what the phone
/// stores, so a shipped id never changes. The tool names are product names and
/// stay in English, so the labels live here and not in the translations. Only
/// [other] has a label that is a word, and the screen translates it.
enum ToolTemplate {
  uptimeKuma(
    id: 'uptime_kuma',
    label: 'Uptime Kuma',
    suggestedName: 'uptime-kuma',
  ),
  healthchecks(
    id: 'healthchecks',
    label: 'Healthchecks',
    suggestedName: 'healthchecks',
  ),
  homeAssistant(
    id: 'home_assistant',
    label: 'Home Assistant',
    suggestedName: 'home-assistant',
  ),
  cron(id: 'cron', label: 'cron', suggestedName: 'cron'),
  ci(id: 'ci', label: 'CI', suggestedName: 'ci'),

  /// Something else. Fills no name. The screen shows a translated label.
  other(id: 'other', label: null, suggestedName: null);

  const ToolTemplate({
    required this.id,
    required this.label,
    required this.suggestedName,
  });

  /// Saved on the phone. Never changes once shipped.
  final String id;

  /// The product name on the chip, or null when the screen translates it.
  final String? label;

  /// The topic name a tap on this chip puts in the name field, or null when
  /// the chip fills nothing.
  final String? suggestedName;

  /// The template with this saved [id], or null for one this build does not
  /// know.
  static ToolTemplate? fromId(String? id) {
    for (final template in values) {
      if (template.id == id) return template;
    }
    return null;
  }
}

/// Which chip is picked and which name a chip last put in the name field.
@immutable
class ToolTemplatePick {
  const ToolTemplatePick({this.selected, this.filledName});

  /// The picked chip, or null when none is.
  final ToolTemplate? selected;

  /// The name a chip last wrote into the field. A later tap may replace the
  /// field only while it still holds exactly this.
  final String? filledName;

  @override
  bool operator ==(Object other) =>
      other is ToolTemplatePick &&
      other.selected == selected &&
      other.filledName == filledName;

  @override
  int get hashCode => Object.hash(selected, filledName);
}

/// What a tap on [tapped] does, given what the name field holds now.
///
/// - A second tap on the picked chip clears the pick and leaves the name.
/// - A tap on another chip picks it. It fills the name only when the field is
///   empty or still holds a name a chip put there, so a chip never overwrites
///   what the user typed.
/// - A chip with no suggested name picks itself and leaves the name.
({ToolTemplatePick pick, String name}) tapToolTemplate({
  required ToolTemplatePick current,
  required String currentName,
  required ToolTemplate tapped,
}) {
  if (current.selected == tapped) {
    return (
      pick: ToolTemplatePick(filledName: current.filledName),
      name: currentName,
    );
  }
  final suggestion = tapped.suggestedName;
  final mayFill =
      currentName.trim().isEmpty ||
      (current.filledName != null && currentName == current.filledName);
  if (suggestion == null || !mayFill) {
    return (
      pick: ToolTemplatePick(
        selected: tapped,
        filledName: current.filledName,
      ),
      name: currentName,
    );
  }
  return (
    pick: ToolTemplatePick(selected: tapped, filledName: suggestion),
    name: suggestion,
  );
}
