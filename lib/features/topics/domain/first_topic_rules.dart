/// Whether the create-topic screen is making the user's first topic.
///
/// True only when the topic list has loaded and holds nothing. While the list
/// is still loading the answer is false, so a returning user never sees the
/// first-topic card flash before their topics arrive.
bool isFirstTopicFor({
  required Set<String> existingNames,
  required bool isListReady,
}) => isListReady && existingNames.isEmpty;
