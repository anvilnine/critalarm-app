import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the template under `topic_tool_template.<topic name>`.
class SharedPrefsToolTemplateStore implements ToolTemplateStore {
  const SharedPrefsToolTemplateStore(this._prefs);

  final SharedPreferences _prefs;

  static const keyPrefix = 'topic_tool_template.';

  @override
  ToolTemplate? read(String topicName) =>
      ToolTemplate.fromId(_prefs.getString('$keyPrefix$topicName'));

  @override
  Future<void> save(String topicName, ToolTemplate template) async {
    await _prefs.setString('$keyPrefix$topicName', template.id);
  }
}
