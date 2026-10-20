import 'dart:async';

import 'package:critalarm/app/quick_action_bindings.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

class _Topics implements TopicRepository {
  @override
  Future<AppResult<List<Topic>>> getTopics() async => <Topic>[].toSuccess();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Actions implements QuickActions {
  final titles = <List<String>>[];
  @override
  Future<void> initialize(QuickActionHandler handler) async {}
  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    titles.add(items.map((item) => item.localizedTitle).toList());
  }

  @override
  Future<void> clearShortcutItems() async {}
}

void _translate(String prefix) => Localization.load(
  const Locale('en'),
  translations: Translations({
    'local_reminders': {
      'quick_incidents': '$prefix history',
      'quick_new_topic': '$prefix new',
    },
  }),
);

void main() {
  test(
    'locale event refreshes titles with the same topics and unsubscribes',
    () async {
      _translate('old');
      final changes = StreamController<void>.broadcast(sync: true);
      final topics = TopicsCubit(GetTopicsUsecase(_Topics()));
      final actions = _Actions();
      final bindings = QuickActionBindings(
        topics: topics,
        navigate: (_) {},
        localeChanges: changes.stream,
        quickActions: actions,
        isWeb: false,
      )..start();
      await Future<void>.delayed(Duration.zero);
      expect(actions.titles.last, ['old history', 'old new']);
      _translate('new');
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(actions.titles.last, ['new history', 'new new']);
      expect(actions.titles.length, 2);
      await bindings.dispose();
      changes.add(null);
      expect(actions.titles.length, 2);
      await topics.close();
      await changes.close();
    },
  );
}
