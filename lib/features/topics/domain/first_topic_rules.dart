import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:flutter/foundation.dart';

/// Whether the create-topic screen is making the user's first topic.
///
/// True only when the topic list has loaded and holds nothing. While the list
/// is still loading the answer is false, so a returning user never sees the
/// first-topic card flash before their topics arrive.
bool isFirstTopicFor({
  required Set<String> existingNames,
  required bool isListReady,
}) => isListReady && existingNames.isEmpty;

/// What to call the token of a topic made in setup, where nobody is asked.
///
/// The picked tool's own name, because that is the one thing that will use
/// the token. With no tool picked the answer is null and the server names
/// it.
String? setupTokenName(ToolTemplate? tool) => tool?.label;

/// How the form on the create-topic screen is laid out.
enum FirstTopicLayout {
  /// A later topic: the name field and the plain Critical row.
  plain,

  /// A first topic made outside setup: the tool chips wrap above the name
  /// field, then the Critical delivery card.
  wrapping,

  /// A first topic made in setup: the name field, the other names, one line
  /// of tool chips, then the Critical delivery card.
  answerFirst,
}

/// The layout for this screen.
///
/// Setup draws [FirstTopicLayout.answerFirst] from its first frame, so what
/// the answer fills is already there before anything is read from the
/// network. It falls back to [FirstTopicLayout.plain] only once the topic
/// list has loaded and holds a topic. A replay shows it whatever the list
/// holds, because it makes nothing and the user may own topics already.
///
/// Anywhere else the first topic keeps the wrapping chips and every later
/// topic is plain, as before.
FirstTopicLayout firstTopicLayoutFor({
  required bool isSetup,
  required bool isReplay,
  required Set<String> existingNames,
  required bool isListReady,
}) {
  if (isSetup) {
    final hasTopics = isListReady && existingNames.isNotEmpty;
    return isReplay || !hasTopics
        ? FirstTopicLayout.answerFirst
        : FirstTopicLayout.plain;
  }
  return isFirstTopicFor(existingNames: existingNames, isListReady: isListReady)
      ? FirstTopicLayout.wrapping
      : FirstTopicLayout.plain;
}

/// What the first topic of setup starts from.
@immutable
class FirstTopicStart {
  const FirstTopicStart({
    required this.name,
    required this.nameChips,
    required this.toolOrder,
    required this.selectedTool,
  });

  /// The topic name the field arrives with, or null for an empty field.
  final String? name;

  /// The other names, one chip each. Empty for none.
  final List<String> nameChips;

  /// The tool chips, left to right.
  final List<ToolTemplate> toolOrder;

  /// The tool that starts picked, or null for none.
  final ToolTemplate? selectedTool;
}

/// What the first topic of setup starts from for the answer [use]. A missing
/// answer reads as [SetupUse.other]: no name, no name chips, nothing picked.
FirstTopicStart firstTopicStartFor(SetupUse? use) {
  final profile = SetupUseProfile.of(effectiveUse(use));
  return FirstTopicStart(
    name: profile.name,
    nameChips: profile.otherNames,
    toolOrder: profile.toolOrder,
    selectedTool: profile.selectedTool,
  );
}
