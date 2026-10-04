import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/data/shared_prefs_tool_template_store.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Progress extends Mock implements OnboardingProgressRepository {}

void main() {
  late SharedPreferences prefs;
  late PrefsFirstTopicHandoff handoff;
  late CreateTopicCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    handoff = PrefsFirstTopicHandoff(prefs);
    cubit =
        CreateTopicCubit(
            CreateTopicUsecase(
              InMemoryTopicRepository(MockApiClient(MockServer())),
            ),
          )
          ..toolTemplates = SharedPrefsToolTemplateStore(prefs)
          ..handoff = handoff
          ..holdsHandoff = true;
    addTearDown(cubit.close);
  });

  Future<String> makeFirstTopic() async {
    cubit.toolTemplateTapped(ToolTemplate.healthchecks);
    await cubit.createTopic();
    expect(cubit.state.status, CreateTopicStatus.success);
    return cubit.state.createdToken!;
  }

  test('the token is in memory after the create and in no prefs key', () async {
    final token = await makeFirstTopic();

    final held = handoff.entry!;
    expect(held.token, token);
    expect(held.topicName, 'healthchecks');
    expect(held.templateId, 'healthchecks');
    for (final key in prefs.getKeys()) {
      expect(
        prefs.get(key).toString().contains(token),
        isFalse,
        reason: 'prefs key $key holds the token',
      );
    }
  });

  test(
    'only the topic name reaches prefs, under onboarding_first_topic',
    () async {
      await makeFirstTopic();

      expect(prefs.getString('onboarding_first_topic'), 'healthchecks');
      expect(handoff.savedTopicName, 'healthchecks');
      // The token's id is kept too, never the token: it lets the last
      // step take the token back if the app dies before showing it.
      expect(
        prefs.getKeys(),
        {
          'onboarding_first_topic',
          'topic_tool_template.healthchecks',
          'onboarding_hook_up_token_id',
        },
      );
    },
  );

  test('the id of the token setup made is saved, so a relaunch can take '
      'the unseen token back', () async {
    final token = await makeFirstTopic();
    final tokenId = cubit.state.createdTopic!.tokenId!;

    expect(handoff.mintedTokenId, tokenId);
    expect(tokenId, isNot(token));

    // After a kill the token is gone from memory and its id is still here,
    // which is what the last step revokes before it makes another.
    final restarted = PrefsFirstTopicHandoff(prefs);
    expect(restarted.entry, isNull);
    expect(restarted.mintedTokenId, tokenId);
  });

  test('outside setup no token id is saved: that token was shown', () async {
    cubit.holdsHandoff = false;
    await makeFirstTopic();
    expect(handoff.mintedTokenId, isNull);
  });

  test('the entry never prints its token', () async {
    final token = await makeFirstTopic();
    expect(handoff.entry.toString().contains(token), isFalse);
  });

  test('a restart keeps the name and loses the entry', () async {
    await makeFirstTopic();
    final restarted = PrefsFirstTopicHandoff(prefs);
    expect(restarted.entry, isNull);
    expect(restarted.savedTopicName, 'healthchecks');
  });

  test('nothing is held outside setup', () async {
    cubit.holdsHandoff = false;
    await makeFirstTopic();
    expect(handoff.entry, isNull);
    expect(prefs.getString('onboarding_first_topic'), isNull);
  });

  test('completing setup clears the memory and the saved name', () async {
    await makeFirstTopic();
    final progress = _Progress();
    when(progress.markCompleted).thenAnswer((_) async => unit.toSuccess());
    when(progress.clearDraft).thenAnswer((_) async => unit.toSuccess());

    await CompleteOnboardingUsecase(progress, null, null, handoff)(
      const NoParams(),
    );

    expect(handoff.entry, isNull);
    expect(handoff.savedTopicName, isNull);
    expect(prefs.getKeys().contains('onboarding_first_topic'), isFalse);
  });

  test('a hold replaces the one before it', () async {
    await handoff.hold(
      const FirstTopicHandoffEntry(
        topicName: 'a',
        serverUrl: 'https://example.test',
        token: 'tk_1',
      ),
    );
    await handoff.hold(
      const FirstTopicHandoffEntry(
        topicName: 'b',
        serverUrl: 'https://example.test',
        token: 'tk_2',
      ),
    );
    expect(handoff.entry!.topicName, 'b');
    expect(handoff.savedTopicName, 'b');
  });
}
