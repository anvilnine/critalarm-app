import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

// What a Look or Wake-up challenge page is for, with nothing drawn: the whole
// phone, or one topic. The pages are the same in both. Only what they read,
// what they write and what their header says differ, and those are here, so
// they are unit tested and the screens only draw the answer.

/// What a pass page changes: the phone's default, or one topic.
@immutable
sealed class PassScope {
  const PassScope();

  /// The topic this scope is for, or null for the whole phone.
  String? get topic;

  bool get isTopic => topic != null;
}

/// The page changes what the phone does everywhere. This is the Personalize
/// page as it always was.
final class EverywhereScope extends PassScope {
  const EverywhereScope();

  @override
  String? get topic => null;

  @override
  bool operator ==(Object other) => other is EverywhereScope;

  @override
  int get hashCode => (EverywhereScope).hashCode;

  @override
  String toString() => 'EverywhereScope()';
}

/// The page changes one topic and nothing else.
final class TopicScope extends PassScope {
  const TopicScope(this.name);

  /// The topic's name, as the topic list holds it. It is the key the choices
  /// are saved under, so it is never trimmed or changed.
  final String name;

  @override
  String? get topic => name;

  @override
  bool operator ==(Object other) => other is TopicScope && other.name == name;

  @override
  int get hashCode => Object.hash(TopicScope, name);

  @override
  String toString() => 'TopicScope($name)';
}

/// The scope a route opens in, from its `topic` query value. A missing or
/// empty value is the whole phone. The router has already decoded the value.
PassScope passScopeFromQuery(String? topic) => topic == null || topic.isEmpty
    ? const EverywhereScope()
    : TopicScope(topic);

/// The location of a pass page for [scope]: [path] alone for the whole
/// phone, or with `?topic=` and the name, encoded.
String passLocationFor(String path, PassScope scope) {
  final topic = scope.topic;
  if (topic == null) return path;
  return Uri(path: path, queryParameters: {'topic': topic}).toString();
}

/// A translation key and the arguments to put in it.
@immutable
class PassLabel {
  const PassLabel(this.key, [this.namedArgs = const {}]);

  final String key;
  final Map<String, String> namedArgs;

  @override
  bool operator ==(Object other) =>
      other is PassLabel &&
      other.key == key &&
      mapEquals(other.namedArgs, namedArgs);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAllUnordered(
      namedArgs.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'PassLabel($key, $namedArgs)';
}

/// The label of a pass page's header, in normal case.
///
/// The Look, Sound and Wake-up challenge pages say which topic they are for
/// when they are opened for one: "Look for {topic}". The other passes have
/// no topic version and keep their plain label.
PassLabel passLabelFor(PassId pass, PassScope scope) {
  final topic = scope.topic;
  final args = {'topic': ?topic};
  return switch (pass) {
    PassId.look when topic != null => PassLabel(
      LocaleKeys.personalize_passes_look_topic_label,
      args,
    ),
    PassId.look => const PassLabel(LocaleKeys.alarm_styles_strip_title),
    PassId.sound when topic != null => PassLabel(
      LocaleKeys.personalize_passes_sound_topic_label,
      args,
    ),
    PassId.sound => const PassLabel(LocaleKeys.personalize_sound_title),
    PassId.challenge when topic != null => PassLabel(
      LocaleKeys.personalize_passes_challenge_topic_label,
      args,
    ),
    PassId.challenge => const PassLabel(LocaleKeys.challenges_strip_title),
    PassId.widgets => const PassLabel(LocaleKeys.personalize_widgets_row),
    PassId.appIcon => const PassLabel(LocaleKeys.personalize_app_icon_row),
  };
}

/// The challenge saved for [scope]: the topic's own, or what a topic made
/// from now on starts with. Null is none. A challenge saved before the plan
/// lapsed is still returned: whether it counts is `shelfChosenFor`'s call.
ChallengeKind? challengeSavedFor(PassScope scope, ChallengeChoices choices) =>
    switch (scope) {
      TopicScope(:final name) => choices.choiceFor(name),
      EverywhereScope() => choices.defaultForNewTopics,
    };

/// Saves the challenge for [scope]. Null takes it away, and needs no plan.
Future<void> saveChallenge(
  PassScope scope,
  ChallengeChoices choices,
  ChallengeKind? kind,
) => switch (scope) {
  TopicScope(:final name) => choices.setChoice(name, kind),
  EverywhereScope() => choices.setDefaultForNewTopics(kind),
};

/// Saves the look for [scope]. Null takes it away: the phone goes back to the
/// standard look, and a topic goes back to the phone's look.
Future<void> saveLook(
  PassScope scope,
  AlarmStyleChoices choices,
  String? styleId,
) => switch (scope) {
  TopicScope(:final name) => choices.setTopicStyle(name, styleId),
  EverywhereScope() => choices.setDefault(styleId),
};

/// Whether the topic has a look of its own, which is when "Same as phone" is
/// there. A page for the whole phone never has it.
bool topicHasOwnLook(PassScope scope, AlarmStyleAssignments saved) =>
    switch (scope) {
      TopicScope(:final name) => saved.perTopic.containsKey(name),
      EverywhereScope() => false,
    };

/// Puts a topic back on the phone's look. Does nothing for the whole phone.
Future<void> followPhoneLook(PassScope scope, AlarmStyleChoices choices) async {
  if (scope is TopicScope) await choices.setTopicStyle(scope.name, null);
}

/// Uses [id] as the look for [scope], once the lock rule says go.
///
/// A free look needs no plan and is saved at once. Any other look asks
/// [mayKeep], which is the lock rule (it waits for the plan, opens the
/// paywall for a locked look, and answers whether the look may be kept now).
/// Nothing is written before it answers yes.
///
/// [afterGo] runs once the answer is yes, before the write. It returns false
/// when the page has gone, and nothing is written then. [write] replaces the
/// plain save, for a photo held in memory that has to be saved as well.
///
/// True when the look was used.
Future<bool> useLook({
  required PassScope scope,
  required AlarmStyleChoices choices,
  required AlarmStyleId id,
  required Future<bool> Function() mayKeep,
  bool Function()? afterGo,
  Future<void> Function()? write,
}) async {
  final go = id.isFree || await mayKeep();
  if (!go) return false;
  if (afterGo != null && !afterGo()) return false;
  if (write != null) {
    await write();
  } else {
    await saveLook(scope, choices, id.id);
  }
  return true;
}
