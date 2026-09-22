import 'package:critalarm/app/quick_action_bindings.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

class _Topics implements TopicRepository {
  @override
  Future<AppResult<List<Topic>>> getTopics() async =>
      const [Topic(name: 'prod-db', critical: true)].toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Fails `initialize` and the first `setShortcutItems`, like a platform
/// that is not ready yet.
class _FlakyQuickActions implements QuickActions {
  int setCalls = 0;
  List<ShortcutItem>? items;

  @override
  Future<void> initialize(QuickActionHandler handler) async =>
      throw StateError('not ready');

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    setCalls++;
    if (setCalls == 1) throw StateError('not ready');
    this.items = items;
  }

  @override
  Future<void> clearShortcutItems() async {}
}

void main() {
  test('a failed platform call never escapes and is tried again', () async {
    final quickActions = _FlakyQuickActions();
    final topics = TopicsCubit(GetTopicsUsecase(_Topics()));
    final bindings = QuickActionBindings(
      topics: topics,
      navigate: (_) {},
      quickActions: quickActions,
      isWeb: false,
    )..start();
    await Future<void>.delayed(Duration.zero);
    expect(quickActions.setCalls, 1);

    await topics.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(quickActions.setCalls, greaterThan(1));
    expect(quickActions.items, isNotNull);

    await bindings.dispose();
    await topics.close();
  });
}
