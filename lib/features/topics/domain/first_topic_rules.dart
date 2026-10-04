import 'package:critalarm/features/topics/domain/tool_template.dart';

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
