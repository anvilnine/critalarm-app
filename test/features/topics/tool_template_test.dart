import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/data/shared_prefs_tool_template_store.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/topic_name_rule.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/features/topics/presentation/formatters/topic_name_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every suggested name passes the topic name rule and the field', () {
    for (final template in ToolTemplate.values) {
      final name = template.suggestedName;
      if (name == null) continue;
      expect(isValidTopicName(name), isTrue, reason: template.id);
      // What the name field would keep of it.
      final formatted = const TopicNameInputFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: name),
      );
      expect(formatted.text, name, reason: template.id);
    }
  });

  test('ids are unique and look up', () {
    final ids = ToolTemplate.values.map((t) => t.id).toSet();
    expect(ids.length, ToolTemplate.values.length);
    for (final template in ToolTemplate.values) {
      expect(ToolTemplate.fromId(template.id), template);
    }
    expect(ToolTemplate.fromId('nope'), isNull);
    expect(ToolTemplate.fromId(null), isNull);
  });

  test('the ids and names are the ones that ship', () {
    expect(
      {
        for (final t in ToolTemplate.values) t.id: t.suggestedName,
      },
      {
        'uptime_kuma': 'uptime-kuma',
        'healthchecks': 'healthchecks',
        'home_assistant': 'home-assistant',
        'cron': 'cron',
        'ci': 'ci',
        'other': null,
      },
    );
  });

  group('tapToolTemplate', () {
    test('fills an empty name', () {
      final result = tapToolTemplate(
        current: const ToolTemplatePick(),
        currentName: '',
        tapped: ToolTemplate.cron,
      );
      expect(result.name, 'cron');
      expect(result.pick.selected, ToolTemplate.cron);
    });

    test('never overwrites what the user typed', () {
      final result = tapToolTemplate(
        current: const ToolTemplatePick(),
        currentName: 'prod-db',
        tapped: ToolTemplate.cron,
      );
      expect(result.name, 'prod-db');
      expect(result.pick.selected, ToolTemplate.cron);
    });

    test('replaces a name a chip put there', () {
      final first = tapToolTemplate(
        current: const ToolTemplatePick(),
        currentName: '',
        tapped: ToolTemplate.cron,
      );
      final second = tapToolTemplate(
        current: first.pick,
        currentName: first.name,
        tapped: ToolTemplate.ci,
      );
      expect(second.name, 'ci');
      expect(second.pick.selected, ToolTemplate.ci);
    });

    test('stops replacing once the user edited the chip name', () {
      final first = tapToolTemplate(
        current: const ToolTemplatePick(),
        currentName: '',
        tapped: ToolTemplate.cron,
      );
      final second = tapToolTemplate(
        current: first.pick,
        currentName: 'cron-nightly',
        tapped: ToolTemplate.ci,
      );
      expect(second.name, 'cron-nightly');
    });

    test('a second tap clears the pick and leaves the name', () {
      final first = tapToolTemplate(
        current: const ToolTemplatePick(),
        currentName: '',
        tapped: ToolTemplate.cron,
      );
      final second = tapToolTemplate(
        current: first.pick,
        currentName: first.name,
        tapped: ToolTemplate.cron,
      );
      expect(second.pick.selected, isNull);
      expect(second.name, 'cron');
    });

    test('Other picks itself and fills nothing', () {
      final result = tapToolTemplate(
        current: const ToolTemplatePick(),
        currentName: '',
        tapped: ToolTemplate.other,
      );
      expect(result.name, '');
      expect(result.pick.selected, ToolTemplate.other);
    });
  });

  group('saving on create', () {
    late SharedPreferences prefs;
    late CreateTopicCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cubit = CreateTopicCubit(
        CreateTopicUsecase(
          InMemoryTopicRepository(MockApiClient(MockServer())),
        ),
      )..toolTemplates = SharedPrefsToolTemplateStore(prefs);
      addTearDown(cubit.close);
    });

    test('a chip tap alone saves nothing', () {
      cubit.toolTemplateTapped(ToolTemplate.uptimeKuma);
      expect(cubit.state.name, 'uptime-kuma');
      expect(prefs.getKeys().where((k) => k.startsWith('topic_tool')), isEmpty);
    });

    test(
      'the id is stored under the topic name once the create works',
      () async {
        cubit.toolTemplateTapped(ToolTemplate.uptimeKuma);
        expect(prefs.getString('topic_tool_template.uptime-kuma'), isNull);

        await cubit.createTopic();

        expect(cubit.state.status, CreateTopicStatus.success);
        expect(
          prefs.getString('topic_tool_template.uptime-kuma'),
          'uptime_kuma',
        );
      },
    );

    test('a topic made with no chip stores nothing', () async {
      cubit.nameChanged('my-topic');
      await cubit.createTopic();
      expect(cubit.state.status, CreateTopicStatus.success);
      expect(prefs.getKeys().where((k) => k.startsWith('topic_tool')), isEmpty);
    });

    test('a refused create stores nothing', () async {
      cubit
        ..toolTemplateTapped(ToolTemplate.cron)
        ..nameChanged('bad name!');
      await cubit.createTopic();
      expect(cubit.state.status, isNot(CreateTopicStatus.success));
      expect(prefs.getKeys().where((k) => k.startsWith('topic_tool')), isEmpty);
    });
  });
}
