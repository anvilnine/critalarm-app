import 'package:critalarm/features/topics/domain/tool_template.dart';

/// Which tool the user said would send to a topic. Kept on the phone only.
/// Nothing about it reaches the server.
abstract interface class ToolTemplateStore {
  /// The template picked for the topic with this name, or null.
  ToolTemplate? read(String topicName);

  Future<void> save(String topicName, ToolTemplate template);
}
