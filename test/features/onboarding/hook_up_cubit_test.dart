import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/in_app_notices/data/repositories/shared_prefs_in_app_notice_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_stats_consent.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_state.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:critalarm/features/topics/data/prefs_first_message_store.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/data/shared_prefs_tool_template_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCreateToken extends Mock implements CreateTopicTokenUsecase {}

class _Telemetry extends NoopTelemetryGate {
  final List<bool> analytics = [];

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async =>
      analytics.add(enabled);
}

class _Timer implements Timer {
  _Timer(this.onFire);

  final void Function() onFire;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

class _Source implements FirstMessageSource {
  List<String> next = const [];
  int polls = 0;
  int baselineReads = 0;

  @override
  Future<List<String>> newerThan(String topic, String since) async {
    polls++;
    return next;
  }

  @override
  Future<FirstMessageBaseline> testBaseline() async {
    baselineReads++;
    return const FirstMessageBaseline.after('m_test');
  }
}

const _server = 'https://api.critalarm.app';
const _token = 'tk_6f1d2c7e-secret';
const _minted = 'tk_9a8b7c6d-minted';

void main() {
  late SharedPreferences prefs;
  late PrefsFirstTopicHandoff handoff;
  late PrefsFirstMessageStore store;
  late SharedPrefsInAppNoticeRepository notices;
  late _MockCreateToken createToken;
  late _Telemetry telemetry;
  late _Source source;
  late List<_Timer> timers;
  late List<bool> answers;
  var topics = <Topic>[];
  String? serverUrl = _server;
  var topicReads = 0;

  HookUpCubit build({bool isReplay = false}) {
    final cubit = HookUpCubit(
      handoff: handoff,
      templates: SharedPrefsToolTemplateStore(prefs),
      createToken: createToken,
      readTopics: () async {
        topicReads++;
        return topics;
      },
      refreshTopics: () async {
        topicReads++;
        return topics;
      },
      readServerUrl: () async => serverUrl,
      watcher: FirstMessageWatcher(
        store: store,
        source: source,
        timer: (_, onFire) {
          final timer = _Timer(onFire);
          timers.add(timer);
          return timer;
        },
      ),
      consent: SetupStatsConsent(
        privacy: SharedPrefsPrivacyRepository(prefs),
        telemetry: telemetry,
        notices: notices,
        onAnswered: ({required isOn}) async => answers.add(isOn),
      ),
      isReplay: isReplay,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> holdFirstTopic({String? templateId}) => handoff.hold(
    FirstTopicHandoffEntry(
      topicName: 'nightly',
      serverUrl: _server,
      token: _token,
      templateId: templateId,
    ),
  );

  setUpAll(() {
    registerFallbackValue(const CreateTopicTokenParams(topicName: ''));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    handoff = PrefsFirstTopicHandoff(prefs);
    store = PrefsFirstMessageStore(prefs);
    notices = SharedPrefsInAppNoticeRepository(prefs);
    createToken = _MockCreateToken();
    telemetry = _Telemetry();
    source = _Source();
    timers = [];
    answers = [];
    topics = [const Topic(name: 'nightly', critical: true)];
    serverUrl = _server;
    topicReads = 0;
    when(() => createToken(any())).thenAnswer(
      (_) async => const TopicToken(
        token: _minted,
        tokenId: 'tok_1',
        name: 'Setup',
      ).toSuccess(),
    );
  });

  group('the token setup made', () {
    test('is the one in the line, and no other is made', () async {
      await holdFirstTopic(templateId: 'cron');
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.ready);
      expect(cubit.state.hasLine, isTrue);
      expect(cubit.state.token, _token);
      expect(cubit.state.topicName, 'nightly');
      expect(cubit.state.serverUrl, _server);
      expect(cubit.state.template, ToolTemplate.cron);
      verifyNever(() => createToken(any()));
    });

    test('shows before the topic list is read', () async {
      await holdFirstTopic();
      final gate = Completer<List<Topic>>();
      final cubit = HookUpCubit(
        handoff: handoff,
        templates: SharedPrefsToolTemplateStore(prefs),
        createToken: createToken,
        readTopics: () => gate.future,
        refreshTopics: () => gate.future,
        readServerUrl: () async => _server,
        watcher: FirstMessageWatcher(
          store: store,
          source: source,
          timer: (_, onFire) => _Timer(onFire),
        ),
        consent: SetupStatsConsent(
          privacy: SharedPrefsPrivacyRepository(prefs),
          telemetry: telemetry,
          notices: notices,
        ),
      );
      addTearDown(cubit.close);

      final loading = cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      expect(cubit.state.hasLine, isTrue);
      expect(cubit.state.isCritical, isNull);

      gate.complete([const Topic(name: 'nightly')]);
      await loading;
      expect(cubit.state.isCritical, isFalse);
    });

    test('the tool comes from the phone when the handoff has none', () async {
      await holdFirstTopic();
      await SharedPrefsToolTemplateStore(
        prefs,
      ).save('nightly', ToolTemplate.uptimeKuma);
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.template, ToolTemplate.uptimeKuma);
    });
  });

  group('the token is gone', () {
    setUp(() async {
      // What a kill leaves behind: the name on the phone, nothing in memory.
      await prefs.setString(PrefsFirstTopicHandoff.topicNameKey, 'nightly');
    });

    test('exactly one named token is made for the topic', () async {
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      final params =
          verify(() => createToken(captureAny())).captured.single
              as CreateTopicTokenParams;
      expect(params.topicName, 'nightly');
      expect(params.name, 'Setup');
      expect(cubit.state.phase, HookUpPhase.ready);
      expect(cubit.state.token, _minted);
      expect(cubit.state.serverUrl, _server);
    });

    test('the wait is its own phase, with no line yet', () async {
      final gate = Completer<AppResult<TopicToken>>();
      when(() => createToken(any())).thenAnswer((_) => gate.future);
      final cubit = build();

      final loading = cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      expect(cubit.state.phase, HookUpPhase.minting);
      expect(cubit.state.isWaiting, isTrue);
      expect(cubit.state.hasLine, isFalse);

      gate.complete(
        const TopicToken(
          token: _minted,
          tokenId: 't',
          name: 'Setup',
        ).toSuccess(),
      );
      await loading;
      expect(cubit.state.hasLine, isTrue);
    });

    test('the new token is held, so a second visit makes none', () async {
      final first = build();
      await first.load(tokenName: 'Setup');
      await first.close();

      final second = build();
      await second.load(tokenName: 'Setup');

      verify(() => createToken(any())).called(1);
      expect(second.state.token, _minted);
    });

    test('a failed mint says so and can be tried again', () async {
      when(() => createToken(any())).thenAnswer(
        (_) async => const Failure.unexpected(message: 'offline').toFailure(),
      );
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.mintFailed);
      expect(cubit.state.mintFailure, isNotNull);
      expect(cubit.state.hasLine, isFalse);
      expect(cubit.state.isWaiting, isFalse, reason: 'Done is never held');

      when(() => createToken(any())).thenAnswer(
        (_) async => const TopicToken(
          token: _minted,
          tokenId: 't',
          name: 'Setup',
        ).toSuccess(),
      );
      await cubit.retryMint();

      expect(cubit.state.phase, HookUpPhase.ready);
      expect(cubit.state.token, _minted);
      expect(cubit.state.mintFailure, isNull);
    });

    test('Try again does nothing once a token is in the line', () async {
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      await cubit.retryMint();
      await cubit.retryMint();

      verify(() => createToken(any())).called(1);
    });

    test('with no name saved it is the first topic on the server', () async {
      await prefs.remove(PrefsFirstTopicHandoff.topicNameKey);
      topics = [const Topic(name: 'prod'), const Topic(name: 'nas')];
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.topicName, 'prod');
    });

    test('no topic on the server: nothing is made', () async {
      topics = [];
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.noTopic);
      verifyNever(() => createToken(any()));
    });

    test('no server: nothing is read or made', () async {
      serverUrl = null;
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.noServer);
      expect(topicReads, 0);
      verifyNever(() => createToken(any()));
    });
  });

  group('the token stays in memory', () {
    test('no prefs key holds it after the screen is used', () async {
      await holdFirstTopic(templateId: 'ci');
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      await cubit.setAnalytics(isOn: true);
      source.next = ['m_1'];
      timers.last.onFire();
      await pumpEventQueue();
      expect(cubit.state.isFirstMessageReceived, isTrue);

      for (final key in prefs.getKeys()) {
        expect(
          prefs.get(key).toString().contains(_token),
          isFalse,
          reason: 'prefs key $key holds the token',
        );
      }
    });

    test('nor a token made here', () async {
      await prefs.setString(PrefsFirstTopicHandoff.topicNameKey, 'nightly');
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      expect(cubit.state.token, _minted);

      for (final key in prefs.getKeys()) {
        expect(prefs.get(key).toString().contains(_minted), isFalse);
      }
    });

    test('printing the state does not print it', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      expect('${cubit.state}'.contains(_token), isFalse);
      expect('${cubit.state}'.contains('tk_'), isFalse);
    });
  });

  group('the first message', () {
    test('is watched for from the setup test message on', () async {
      await holdFirstTopic();
      final cubit = build();

      await cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      expect(store.cursorFor('nightly'), 'm_test');
      expect(cubit.state.isFirstMessageReceived, isFalse);
    });

    test('turns the row when it lands', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      source.next = ['m_1'];
      timers.last.onFire();
      await pumpEventQueue();

      expect(cubit.state.isFirstMessageReceived, isTrue);
      expect(store.isReceived, isTrue);
    });

    test('shows as landed at once on a phone that already has it', () async {
      await store.markReceived();
      await holdFirstTopic();
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.isFirstMessageReceived, isTrue);
      expect(source.polls, 0);
    });

    test(
      'the watch stops in the background and when the step closes',
      () async {
        await holdFirstTopic();
        final cubit = build();
        await cubit.load(tokenName: 'Setup');
        await pumpEventQueue();
        final polls = source.polls;

        cubit.appPaused();
        expect(timers.last.cancelled, isTrue);

        cubit.appResumed();
        await pumpEventQueue();
        expect(source.polls, polls + 1);

        final waiting = timers.last;
        await cubit.close();
        expect(waiting.cancelled, isTrue);
      },
    );
  });

  group('the analytics switch', () {
    test('starts off, and leaving it off is no answer', () async {
      await holdFirstTopic();
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.isAnalyticsOn, isFalse);
      expect(notices.getConsentAskedAt(), isNull);
      expect(telemetry.analytics, isEmpty);
      expect(prefs.containsKey('privacy_analytics_enabled'), isFalse);
      expect(answers, isEmpty);
    });

    test('turning it on saves the choice Settings reads', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      await cubit.setAnalytics(isOn: true);

      expect(cubit.state.isAnalyticsOn, isTrue);
      expect(prefs.getBool('privacy_analytics_enabled'), isTrue);
      expect(telemetry.analytics, [true]);
      expect(notices.getConsentAskedAt(), isNotNull);
      expect(answers, [true]);
    });

    test('turning it back off is an answer too', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      await cubit.setAnalytics(isOn: true);
      await cubit.setAnalytics(isOn: false);

      expect(cubit.state.isAnalyticsOn, isFalse);
      expect(prefs.getBool('privacy_analytics_enabled'), isFalse);
      expect(telemetry.analytics, [true, false]);
      expect(notices.getConsentAskedAt(), isNotNull);
      expect(answers, [true, false]);
    });

    test('shows on when analytics was already chosen', () async {
      await prefs.setBool('privacy_analytics_enabled', true);
      await holdFirstTopic();
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.isAnalyticsOn, isTrue);
      expect(notices.getConsentAskedAt(), isNull);
    });
  });

  group('a replay', () {
    test('shows made-up values and writes nothing', () async {
      await holdFirstTopic();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final cubit = build(isReplay: true);

      await cubit.load(tokenName: 'Setup');
      await cubit.setAnalytics(isOn: true);
      cubit
        ..appPaused()
        ..appResumed();
      await cubit.retryMint();
      await pumpEventQueue();

      expect(cubit.state.isExample, isTrue);
      expect(cubit.state.hasLine, isTrue);
      expect(cubit.state.token, HookUpCubit.exampleToken);
      expect(cubit.state.token, isNot(_token));
      expect(cubit.state.topicName, HookUpCubit.exampleTopic);
      expect(cubit.state.isAnalyticsOn, isTrue, reason: 'the switch moves');
      expect(
        {for (final key in prefs.getKeys()) key: prefs.get(key)},
        before,
      );
      expect(source.polls, 0);
      expect(source.baselineReads, 0);
      expect(topicReads, 0);
      expect(telemetry.analytics, isEmpty);
      expect(answers, isEmpty);
      verifyNever(() => createToken(any()));
    });

    test('can be put on a state to look at', () async {
      final cubit = build(isReplay: true);
      await cubit.load(tokenName: 'Setup');

      cubit.showForReplay(
        phase: HookUpPhase.mintFailed,
        template: ToolTemplate.healthchecks,
        isFirstMessageReceived: true,
      );

      expect(cubit.state.phase, HookUpPhase.mintFailed);
      expect(cubit.state.template, ToolTemplate.healthchecks);
      expect(cubit.state.isFirstMessageReceived, isTrue);
    });

    test('a real run cannot be put on a state', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      cubit.showForReplay(phase: HookUpPhase.mintFailed);

      expect(cubit.state.phase, HookUpPhase.ready);
    });
  });
}
