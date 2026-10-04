import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/in_app_notices/data/repositories/shared_prefs_in_app_notice_repository.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/setup_stats_consent.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_state.dart';
import 'package:critalarm/features/settings/data/repositories/observed_privacy_repository.dart';
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

import 'support/fake_setup_test_ring.dart';

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
  final List<String> sinces = [];

  @override
  Future<FirstMessagePage> read(String topic, String since) async {
    polls++;
    sinces.add(since);
    // The first read is the baseline: the setup test message.
    if (since == FirstMessageSource.everything) {
      return const FirstMessagePage(candidates: [], newestId: 'm_test');
    }
    return FirstMessagePage(
      candidates: next,
      newestId: next.isEmpty ? null : next.last,
    );
  }
}

class _MockRevokeToken extends Mock implements RevokeTopicTokenUsecase {}

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

  late StreamController<String> alarms;
  late FakeSetupTestRing ring;
  late _MockRevokeToken revokeToken;
  var incidentTopics = <String, String>{};
  var isSetupComplete = false;

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
        privacy: ObservedPrivacyRepository(
          SharedPrefsPrivacyRepository(prefs),
          onAnalyticsChoice: ({required isOn}) async => answers.add(isOn),
        ),
        telemetry: telemetry,
      ),
      revokeToken: revokeToken,
      ring: ring,
      isSetupComplete: () async => isSetupComplete,
      alarmArrivals: alarms.stream,
      readIncidentTopic: (id) async => incidentTopics[id],
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
    registerFallbackValue(
      const RevokeTopicTokenParams(topicName: '', tokenId: ''),
    );
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
    alarms = StreamController<String>.broadcast();
    ring = FakeSetupTestRing();
    revokeToken = _MockRevokeToken();
    incidentTopics = {'inc_mine': 'nightly', 'inc_one': 'nightly'};
    isSetupComplete = false;
    when(
      () => revokeToken(any()),
    ).thenAnswer((_) async => unit.toSuccess());
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

    test('an entry handed on with no address takes the saved one', () async {
      await handoff.hold(
        const FirstTopicHandoffEntry(
          topicName: 'nightly',
          serverUrl: '',
          token: _token,
        ),
      );
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.ready);
      expect(cubit.state.serverUrl, _server);
      expect(cubit.state.token, _token);
      expect(handoff.entry!.serverUrl, _server);
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
        ),
        revokeToken: revokeToken,
        ring: ring,
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

    test(
      'with no name saved no topic is guessed and nothing is made',
      () async {
        await prefs.remove(PrefsFirstTopicHandoff.topicNameKey);
        topics = [const Topic(name: 'prod'), const Topic(name: 'nas')];
        final cubit = build();

        await cubit.load(tokenName: 'Setup');

        expect(cubit.state.phase, HookUpPhase.noTopic);
        expect(cubit.state.topicName, isNull);
        expect(source.polls, 0);
        verifyNever(() => createToken(any()));
      },
    );

    test('a saved name the server no longer has is no topic', () async {
      topics = [const Topic(name: 'prod')];
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.noTopic);
      verifyNever(() => createToken(any()));
    });

    test('the id of the token made is saved, never its value', () async {
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(handoff.mintedTokenId, 'tok_1');
      verifyNever(() => revokeToken(any()));
    });

    test(
      'a cold start takes the earlier token back before making one',
      () async {
        // An earlier launch made tok_old, then the app was killed.
        await handoff.saveMintedTokenId('tok_old');
        final order = <String>[];
        when(() => revokeToken(any())).thenAnswer((_) async {
          order.add('revoke');
          return unit.toSuccess();
        });
        when(() => createToken(any())).thenAnswer((_) async {
          order.add('create');
          return const TopicToken(
            token: _minted,
            tokenId: 'tok_new',
            name: 'Setup',
          ).toSuccess();
        });
        final cubit = build();

        await cubit.load(tokenName: 'Setup');

        final revoked =
            verify(() => revokeToken(captureAny())).captured.single
                as RevokeTopicTokenParams;
        expect(revoked.topicName, 'nightly');
        expect(revoked.tokenId, 'tok_old');
        expect(order, ['revoke', 'create']);
        expect(handoff.mintedTokenId, 'tok_new');
        expect(cubit.state.token, _minted);
      },
    );

    test('three cold starts leave one token of this step, not three', () async {
      final live = <String>{};
      var made = 0;
      when(() => createToken(any())).thenAnswer((_) async {
        made++;
        live.add('tok_$made');
        return TopicToken(
          token: 'tk_secret_$made',
          tokenId: 'tok_$made',
          name: 'Setup',
        ).toSuccess();
      });
      when(() => revokeToken(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.single as RevokeTopicTokenParams;
        live.remove(params.tokenId);
        return unit.toSuccess();
      });

      for (var launch = 0; launch < 3; launch++) {
        // A cold start: nothing in memory, the prefs as they were left.
        handoff = PrefsFirstTopicHandoff(prefs);
        final cubit = build();
        await cubit.load(tokenName: 'Setup');
        await cubit.close();
      }

      expect(made, 3);
      expect(live, {'tok_3'});
    });

    test(
      'an earlier token already gone from the server is no obstacle',
      () async {
        await handoff.saveMintedTokenId('tok_old');
        when(() => revokeToken(any())).thenAnswer(
          (_) async => const Failure.api(
            statusCode: 404,
            message: 'not found',
          ).toFailure(),
        );
        final cubit = build();

        await cubit.load(tokenName: 'Setup');

        expect(cubit.state.phase, HookUpPhase.ready);
        verify(() => createToken(any())).called(1);
      },
    );

    test('when the earlier token cannot be taken back none is made', () async {
      await handoff.saveMintedTokenId('tok_old');
      when(() => revokeToken(any())).thenAnswer(
        (_) async => const Failure.unexpected(message: 'offline').toFailure(),
      );
      final cubit = build();

      await cubit.load(tokenName: 'Setup');

      expect(cubit.state.phase, HookUpPhase.mintFailed);
      expect(handoff.mintedTokenId, 'tok_old');
      verifyNever(() => createToken(any()));
    });

    test('the saved id goes when setup completes', () async {
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      expect(handoff.mintedTokenId, isNotNull);

      await handoff.clear();

      expect(handoff.mintedTokenId, isNull);
      expect(
        prefs.containsKey(PrefsFirstTopicHandoff.mintedTokenIdKey),
        isFalse,
      );
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

  group('a user who already finished setup', () {
    test('gets nothing read, made, watched or saved', () async {
      isSetupComplete = true;
      await prefs.setString(PrefsFirstTopicHandoff.topicNameKey, 'nightly');
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final cubit = build();

      await cubit.load(tokenName: 'Setup');
      alarms.add('inc_mine');
      await pumpEventQueue();

      expect(cubit.state.phase, HookUpPhase.noTopic);
      expect(cubit.state.hasLine, isFalse);
      expect(topicReads, 0);
      expect(source.polls, 0);
      expect(cubit.state.ringingIncidentId, isNull);
      expect(
        {for (final key in prefs.getKeys()) key: prefs.get(key)},
        before,
      );
      verifyNever(() => createToken(any()));
      verifyNever(() => revokeToken(any()));
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
      expect(source.sinces.first, FirstMessageSource.everything);
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

  group('an alarm from the curl line', () {
    test('turns the row at once and names the incident', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      await pumpEventQueue();
      final polls = source.polls;

      alarms.add('inc_mine');
      await pumpEventQueue();

      expect(cubit.state.isFirstMessageReceived, isTrue);
      expect(cubit.state.ringingIncidentId, 'inc_mine');
      expect(store.isReceived, isTrue);
      expect(source.polls, polls, reason: 'no poll was needed');
      expect(timers.last.cancelled, isTrue, reason: 'the polling ended');
    });

    test('the alarm is recorded as one setup asked for', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      alarms.add('inc_mine');
      await pumpEventQueue();

      expect(ring.setupIncidentIds, contains('inc_mine'));
      expect(ring.incidentIds, isNot(contains('inc_mine')));
    });

    test('an alarm on another topic is not the first message', () async {
      incidentTopics['inc_other'] = 'prod';
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      alarms.add('inc_other');
      await pumpEventQueue();

      expect(cubit.state.isFirstMessageReceived, isFalse);
      expect(cubit.state.ringingIncidentId, isNull);
      expect(store.isReceived, isFalse);
      expect(ring.setupIncidentIds, isEmpty);
    });

    test(
      'an alarm whose topic cannot be read is not the first message',
      () async {
        await holdFirstTopic();
        final cubit = build();
        await cubit.load(tokenName: 'Setup');
        await pumpEventQueue();

        alarms.add('inc_unknown');
        await pumpEventQueue();

        expect(cubit.state.ringingIncidentId, isNull);
        expect(store.isReceived, isFalse);
      },
    );

    test('the test of this phone only is not the first message', () async {
      // A tap on its leftover notification arrives here as an alarm.
      incidentTopics[phoneOnlyTestIncidentId] = 'nightly';
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      alarms.add(phoneOnlyTestIncidentId);
      await pumpEventQueue();

      expect(cubit.state.isFirstMessageReceived, isFalse);
      expect(cubit.state.ringingIncidentId, isNull);
      expect(store.isReceived, isFalse);
    });

    test('a setup test ringing late is not the first message', () async {
      await ring.hold('inc_test');
      incidentTopics['inc_test'] = 'nightly';
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');
      await pumpEventQueue();

      alarms.add('inc_test');
      await pumpEventQueue();

      expect(cubit.state.isFirstMessageReceived, isFalse);
      expect(cubit.state.ringingIncidentId, isNull);
      expect(store.isReceived, isFalse);
    });

    test('only the first alarm is handed over', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      alarms.add('inc_one');
      await pumpEventQueue();
      alarms.add('inc_two');
      await pumpEventQueue();

      expect(cubit.state.ringingIncidentId, 'inc_one');
    });

    test('a replay does not listen for alarms', () async {
      final cubit = build(isReplay: true);
      await cubit.load(tokenName: 'Setup');

      alarms.add('inc_mine');
      await pumpEventQueue();

      expect(cubit.state.ringingIncidentId, isNull);
      expect(cubit.state.isFirstMessageReceived, isFalse);
      expect(store.isReceived, isFalse);
    });
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
      expect(answers, [true]);
      // The Home sheet still gets its turn: it also offers crash reports.
      expect(notices.getConsentAskedAt(), isNull);
    });

    test('turning it back off turns analytics off again', () async {
      await holdFirstTopic();
      final cubit = build();
      await cubit.load(tokenName: 'Setup');

      await cubit.setAnalytics(isOn: true);
      await cubit.setAnalytics(isOn: false);

      expect(cubit.state.isAnalyticsOn, isFalse);
      expect(prefs.getBool('privacy_analytics_enabled'), isFalse);
      expect(telemetry.analytics, [true, false]);
      expect(notices.getConsentAskedAt(), isNull);
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
