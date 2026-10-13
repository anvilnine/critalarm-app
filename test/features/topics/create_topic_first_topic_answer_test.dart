import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/first_topic_rules.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';

class _Templates implements ToolTemplateStore {
  final Map<String, ToolTemplate> saved = {};

  @override
  ToolTemplate? read(String topicName) => saved[topicName];

  @override
  Future<void> save(String topicName, ToolTemplate template) async {
    saved[topicName] = template;
  }
}

void main() {
  late _Templates templates;

  /// The cubit as setup builds it: a one-step screen, the list loaded and
  /// empty.
  CreateTopicCubit setupCubit({
    bool isReplay = false,
    Iterable<String> existing = const [],
    bool isListReady = true,
  }) {
    final cubit =
        CreateTopicCubit(
            CreateTopicUsecase(
              InMemoryTopicRepository(MockApiClient(MockServer())),
            ),
          )
          ..toolTemplates = templates
          ..isOneStep = true
          ..isReplay = isReplay
          ..existingNamesChanged(existing, isListReady: isListReady);
    addTearDown(cubit.close);
    return cubit;
  }

  setUp(() => templates = _Templates());

  group('firstTopicStartFor', () {
    test('servers: prod-db, three names, curl first and picked', () {
      final start = firstTopicStartFor(SetupUse.servers);
      expect(start.name, 'prod-db');
      expect(start.nameChips, ['prod-api', 'client-vps', 'deploy-failed']);
      expect(start.toolOrder, [
        ToolTemplate.curl,
        ToolTemplate.cron,
        ToolTemplate.ci,
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.homeAssistant,
      ]);
      expect(start.selectedTool, ToolTemplate.curl);
    });

    test('homelab: uptime-kuma, three names, Uptime Kuma first and picked', () {
      final start = firstTopicStartFor(SetupUse.homelab);
      expect(start.name, 'uptime-kuma');
      expect(start.nameChips, ['homelab', 'nas-disk', 'backup-job']);
      expect(start.toolOrder, [
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.homeAssistant,
        ToolTemplate.cron,
        ToolTemplate.ci,
        ToolTemplate.curl,
      ]);
      expect(start.selectedTool, ToolTemplate.uptimeKuma);
    });

    test('jobs: nightly-backup, three names, CI first and picked', () {
      final start = firstTopicStartFor(SetupUse.jobs);
      expect(start.name, 'nightly-backup');
      expect(start.nameChips, ['ci', 'deploy', 'cron']);
      expect(start.toolOrder, [
        ToolTemplate.ci,
        ToolTemplate.cron,
        ToolTemplate.healthchecks,
        ToolTemplate.curl,
        ToolTemplate.uptimeKuma,
        ToolTemplate.homeAssistant,
      ]);
      expect(start.selectedTool, ToolTemplate.ci);
    });

    test('home: home-assistant, three names, Home Assistant first', () {
      final start = firstTopicStartFor(SetupUse.home);
      expect(start.name, 'home-assistant');
      expect(start.nameChips, ['freezer', 'garage-door', 'washer']);
      expect(start.toolOrder, [
        ToolTemplate.homeAssistant,
        ToolTemplate.curl,
        ToolTemplate.cron,
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.ci,
      ]);
      expect(start.selectedTool, ToolTemplate.homeAssistant);
    });

    test('something else and no answer: no name, no names, nothing picked', () {
      for (final use in [SetupUse.other, null]) {
        final start = firstTopicStartFor(use);
        expect(start.name, isNull, reason: '$use');
        expect(start.nameChips, isEmpty, reason: '$use');
        expect(start.selectedTool, isNull, reason: '$use');
        expect(start.toolOrder, [
          ToolTemplate.uptimeKuma,
          ToolTemplate.healthchecks,
          ToolTemplate.homeAssistant,
          ToolTemplate.cron,
          ToolTemplate.ci,
          ToolTemplate.curl,
        ]);
      }
    });

    test('every answer lists each tool with a chip once', () {
      final chipTools = ToolTemplate.values.where((t) => t.label != null);
      for (final use in [...SetupUse.values, null]) {
        final order = firstTopicStartFor(use).toolOrder;
        expect(order.toSet(), chipTools.toSet(), reason: '$use');
        expect(order.length, chipTools.length, reason: '$use');
      }
    });

    test('is the answer table and nothing else', () {
      for (final use in SetupUse.values) {
        final profile = SetupUseProfile.of(use);
        final start = firstTopicStartFor(use);
        expect(start.name, profile.name);
        expect(start.nameChips, profile.otherNames);
        expect(start.toolOrder, profile.toolOrder);
        expect(start.selectedTool, profile.selectedTool);
      }
    });

    test('a picked tool with a suggested name never matches its own name', () {
      // The answer's name is its own, so a tap on another tool is what
      // replaces it. Nothing here may depend on the picked tool's name.
      for (final use in SetupUse.values) {
        final start = firstTopicStartFor(use);
        if (start.name == null) continue;
        expect(start.nameChips, isNot(contains(start.name)));
      }
    });
  });

  group('firstTopicLayoutFor', () {
    FirstTopicLayout layout({
      bool isSetup = false,
      bool isReplay = false,
      Set<String> names = const {},
      bool ready = true,
    }) => firstTopicLayoutFor(
      isSetup: isSetup,
      isReplay: isReplay,
      existingNames: names,
      isListReady: ready,
    );

    test('setup draws the answer layout before the list has loaded', () {
      expect(layout(isSetup: true, ready: false), FirstTopicLayout.answerFirst);
      expect(layout(isSetup: true), FirstTopicLayout.answerFirst);
    });

    test('setup with a topic in the list is plain', () {
      expect(layout(isSetup: true, names: {'a'}), FirstTopicLayout.plain);
    });

    test('a replay shows the answer layout whatever the user owns', () {
      expect(
        layout(isSetup: true, isReplay: true, names: {'a'}),
        FirstTopicLayout.answerFirst,
      );
    });

    test('outside setup the first topic keeps the wrapping chips', () {
      expect(layout(), FirstTopicLayout.wrapping);
    });

    test('outside setup it waits for the list, and a later topic is plain', () {
      expect(layout(ready: false), FirstTopicLayout.plain);
      expect(layout(names: {'a'}), FirstTopicLayout.plain);
    });
  });

  group('applySetupUse', () {
    test('servers: the name, curl picked, the name counts as a chip name', () {
      final cubit = setupCubit()..applySetupUse(SetupUse.servers);
      expect(cubit.state.name, 'prod-db');
      expect(cubit.state.selectedTool, ToolTemplate.curl);
      expect(cubit.state.toolPick.filledName, 'prod-db');
      expect(cubit.state.isCritical, isFalse);
    });

    test('every answer with a name fills it and picks its tool', () {
      for (final use in SetupUse.values) {
        final start = firstTopicStartFor(use);
        if (start.name == null) continue;
        final cubit = setupCubit()..applySetupUse(use);
        expect(cubit.state.name, start.name, reason: '$use');
        expect(cubit.state.selectedTool, start.selectedTool, reason: '$use');
        expect(cubit.state.toolPick.filledName, start.name, reason: '$use');
      }
    });

    test(
      'something else and no answer leave the name empty, nothing picked',
      () {
        for (final use in [SetupUse.other, null]) {
          final cubit = setupCubit()..applySetupUse(use);
          expect(cubit.state.name, isEmpty, reason: '$use');
          expect(cubit.state.selectedTool, isNull, reason: '$use');
          expect(cubit.state.toolPick.filledName, isNull, reason: '$use');
        }
      },
    );

    test('a tap on Uptime Kuma replaces the name the answer filled', () {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..toolTemplateTapped(ToolTemplate.uptimeKuma);
      expect(cubit.state.name, 'uptime-kuma');
      expect(cubit.state.selectedTool, ToolTemplate.uptimeKuma);
    });

    test('a name typed first is kept when a tool is tapped', () {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..nameChanged('x')
        ..toolTemplateTapped(ToolTemplate.uptimeKuma);
      expect(cubit.state.name, 'x');
      expect(cubit.state.selectedTool, ToolTemplate.uptimeKuma);
    });

    test('a name chip replaces a typed name, and keeps the picked tool', () {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..nameChanged('x')
        ..nameChipTapped('prod-api');
      expect(cubit.state.name, 'prod-api');
      expect(cubit.state.selectedTool, ToolTemplate.curl);
      expect(cubit.state.toolPick.filledName, 'prod-api');
    });

    test('a name chip then a tool: the tool replaces the chip name', () {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..nameChipTapped('prod-api')
        ..toolTemplateTapped(ToolTemplate.cron);
      expect(cubit.state.name, 'cron');
    });

    test('a name chip clears an error', () {
      final cubit = setupCubit(existing: const ['prod-db'])
        ..nameChanged('')
        ..nextStep();
      expect(cubit.state.errorMessage, isNotNull);
      cubit.nameChipTapped('prod-api');
      expect(cubit.state.errorMessage, isNull);
    });

    test('a second tap on the picked chip clears the pick, keeps the name', () {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..toolTemplateTapped(ToolTemplate.curl);
      expect(cubit.state.selectedTool, isNull);
      expect(cubit.state.name, 'prod-db');
    });

    test('does nothing when the screen is not a setup step', () {
      final cubit = setupCubit()
        ..isOneStep = false
        ..applySetupUse(SetupUse.servers);
      expect(cubit.state.name, isEmpty);
      expect(cubit.state.selectedTool, isNull);
    });

    test('does nothing for a later topic', () {
      final cubit = setupCubit(existing: const ['prod-db'])
        ..applySetupUse(SetupUse.homelab);
      expect(cubit.state.name, isEmpty);
      expect(cubit.state.selectedTool, isNull);
    });

    test('fills before the list has loaded', () {
      final cubit = setupCubit(isListReady: false)
        ..applySetupUse(SetupUse.jobs);
      expect(cubit.state.name, 'nightly-backup');
      expect(cubit.state.selectedTool, ToolTemplate.ci);
    });

    test('a list that arrives with a topic takes an untouched fill back', () {
      final cubit = setupCubit(isListReady: false)
        ..applySetupUse(SetupUse.jobs)
        ..existingNamesChanged(const ['old'], isListReady: true);
      expect(cubit.state.name, isEmpty);
      expect(cubit.state.selectedTool, isNull);
    });

    test('a list that arrives with a topic keeps a name the user typed', () {
      final cubit = setupCubit(isListReady: false)
        ..applySetupUse(SetupUse.jobs)
        ..nameChanged('mine')
        ..existingNamesChanged(const ['old'], isListReady: true);
      expect(cubit.state.name, 'mine');
    });

    test('a list that arrives empty keeps the fill', () {
      final cubit = setupCubit(isListReady: false)
        ..applySetupUse(SetupUse.jobs)
        ..existingNamesChanged(const [], isListReady: true);
      expect(cubit.state.name, 'nightly-backup');
    });

    test('a replay fills the name even when the user owns topics', () {
      final cubit = setupCubit(isReplay: true, existing: const ['old'])
        ..applySetupUse(SetupUse.home);
      expect(cubit.state.name, 'home-assistant');
      expect(cubit.state.selectedTool, ToolTemplate.homeAssistant);
    });

    test('a second call changes nothing', () {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..nameChanged('mine')
        ..applySetupUse(SetupUse.homelab);
      expect(cubit.state.name, 'mine');
      expect(cubit.state.selectedTool, ToolTemplate.curl);
    });
  });

  group('outside setup', () {
    test('a tool from the route fills and picks as it always did', () {
      final cubit = CreateTopicCubit(
        CreateTopicUsecase(
          InMemoryTopicRepository(MockApiClient(MockServer())),
        ),
      )..existingNamesChanged(const <String>[], isListReady: true);
      addTearDown(cubit.close);

      cubit.toolTemplateTapped(ToolTemplate.cron);
      expect(cubit.state.name, 'cron');
      expect(cubit.state.selectedTool, ToolTemplate.cron);
    });

    test('the answer fills nothing', () {
      final cubit =
          CreateTopicCubit(
              CreateTopicUsecase(
                InMemoryTopicRepository(MockApiClient(MockServer())),
              ),
            )
            ..existingNamesChanged(const <String>[], isListReady: true)
            ..applySetupUse(SetupUse.servers);
      addTearDown(cubit.close);

      expect(cubit.state.name, isEmpty);
      expect(cubit.state.selectedTool, isNull);
    });
  });

  group('creating the topic', () {
    test('saves the picked tool, curl included', () async {
      final cubit = setupCubit()..applySetupUse(SetupUse.servers);
      await cubit.createTopic();
      expect(cubit.state.status, CreateTopicStatus.success);
      expect(templates.saved, {'prod-db': ToolTemplate.curl});
    });

    test('saves the tool tapped after the answer filled one', () async {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.servers)
        ..toolTemplateTapped(ToolTemplate.healthchecks);
      await cubit.createTopic();
      expect(templates.saved, {'healthchecks': ToolTemplate.healthchecks});
    });

    test('names the token after curl', () async {
      final cubit = setupCubit()..applySetupUse(SetupUse.servers);
      await cubit.createTopic();
      expect(cubit.state.createdTopic!.tokenName, 'curl');
    });

    test('saves no tool for something else', () async {
      final cubit = setupCubit()
        ..applySetupUse(SetupUse.other)
        ..nameChanged('my-topic');
      await cubit.createTopic();
      expect(templates.saved, isEmpty);
    });

    test('Critical delivery stays off', () async {
      final cubit = setupCubit()..applySetupUse(SetupUse.home);
      await cubit.createTopic();
      expect(cubit.state.createdTopic!.critical, isFalse);
    });

    test('a filled name that is taken shows the duplicate error', () async {
      final cubit = setupCubit(existing: const ['prod-db'], isReplay: true)
        ..applySetupUse(SetupUse.servers);
      expect(cubit.state.name, 'prod-db');
      expect(cubit.state.isDuplicateName, isTrue);

      await cubit.createTopic();
      expect(cubit.state.status, CreateTopicStatus.initial);
      expect(
        cubit.state.errorMessage,
        LocaleKeys.api_errors_topic_already_exists.tr(),
      );
    });
  });
}
