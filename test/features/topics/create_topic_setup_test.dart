import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/topic_made_beat.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/create_topic_screen.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/load_translations.dart';

class _Create extends Mock implements CreateTopicUsecase {}

class _Connections implements ConnectionRepository {
  _Connections(this.connection);

  ServerConnection? connection;

  /// Held open until the test lets it go, to stand in for a slow load.
  Future<void>? gate;

  @override
  Future<AppResult<ServerConnection>> getConnection() async {
    await gate;
    final saved = connection;
    return saved == null
        ? const Failure.notFound().toFailure()
        : saved.toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _server = 'https://api.critalarm.app';

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    registerFallbackValue(const CreateTopicParams(name: 'x'));
  });

  group('the one-step create when the server says no', () {
    late _Create create;
    late PrefsFirstTopicHandoff handoff;
    late CreateTopicCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      handoff = PrefsFirstTopicHandoff(await SharedPreferences.getInstance());
      create = _Create();
      cubit = CreateTopicCubit(create)
        ..handoff = handoff
        ..holdsHandoff = true
        ..isOneStep = true
        ..nameChanged('setup-test');
      addTearDown(cubit.close);
    });

    Future<void> failWith(Failure failure) async {
      when(() => create(any())).thenAnswer((_) async => failure.toFailure());
      await cubit.createTopic();
    }

    void expectNothingMade() {
      expect(cubit.state.status, CreateTopicStatus.failure);
      expect(cubit.state.step, CreateTopicStep.topic);
      expect(cubit.state.createdToken, isNull);
      expect(cubit.state.errorMessage, isNotNull);
      expect(handoff.entry, isNull);
      expect(handoff.savedTopicName, isNull);
      expect(handoff.mintedTokenId, isNull);
    }

    test(
      'the critical topic cap: an error on the form, nothing handed on',
      () async {
        await failWith(
          const Failure.api(statusCode: 429, cap: 'critical_topics'),
        );
        expectNothingMade();
        expect(cubit.state.capReached?.name, 'critical_topics');
      },
    );

    test(
      'offline: an error on the form, and the name is still there',
      () async {
        await failWith(const Failure.unexpected(message: 'SocketException'));
        expectNothingMade();
        expect(cubit.state.name, 'setup-test');
        expect(cubit.state.capReached, isNull);
      },
    );

    test(
      'a server error: the same, and a second try can still succeed',
      () async {
        await failWith(const Failure.api(statusCode: 500));
        expectNothingMade();

        when(() => create(any())).thenAnswer(
          (_) async => const Topic(
            name: 'setup-test',
            token: 'tk_secret',
            tokenId: 'tok_1',
          ).toSuccess(),
        );
        await cubit.createTopic();
        expect(cubit.state.status, CreateTopicStatus.success);
        expect(handoff.entry!.token, 'tk_secret');
        expect(handoff.mintedTokenId, 'tok_1');
      },
    );
  });

  group('the server address handed on', () {
    late _Create create;
    late PrefsFirstTopicHandoff handoff;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      handoff = PrefsFirstTopicHandoff(await SharedPreferences.getInstance());
      create = _Create();
      when(() => create(any())).thenAnswer(
        (_) async => const Topic(
          name: 'setup-test',
          token: 'tk_secret',
          tokenId: 'tok_1',
        ).toSuccess(),
      );
    });

    test('a Create tapped before the screen has loaded its address still '
        'hands the saved one on', () async {
      final connections = _Connections(
        const ServerConnection(serverUrl: _server, adminToken: 'ad_x'),
      );
      final cubit = CreateTopicCubit(create, GetConnectionUsecase(connections))
        ..handoff = handoff
        ..holdsHandoff = true
        ..isOneStep = true
        ..nameChanged('setup-test');
      addTearDown(cubit.close);

      // loadConnection has not run: the state holds no address.
      expect(cubit.state.serverUrl, isEmpty);
      await cubit.createTopic();

      expect(handoff.entry!.serverUrl, _server);
    });

    test(
      'the address is in the state as soon as the connection is read',
      () async {
        final connections = _Connections(
          const ServerConnection(serverUrl: _server, adminToken: 'ad_x'),
        );
        final cubit = CreateTopicCubit(
          create,
          GetConnectionUsecase(connections),
        );
        addTearDown(cubit.close);
        final seen = <String>[];
        final sub = cubit.stream.listen((state) => seen.add(state.serverUrl));
        addTearDown(sub.cancel);

        await cubit.loadConnection();
        await pumpEventQueue();

        expect(seen.first, _server);
      },
    );
  });

  group('the setup screen', () {
    setUpAll(() => configureDependencies(useMockApi: true));

    late int doneCalls;

    setUp(() {
      getIt<MockServer>().reset();
      doneCalls = 0;
    });

    Widget app({bool isReplay = false}) => BlocProvider<TopicsCubit>.value(
      value: getIt<TopicsCubit>(),
      child: MaterialApp(
        theme: buildLightTheme(),
        home: CreateTopicScreen(
          isReplay: isReplay,
          onDone: () => doneCalls++,
        ),
      ),
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    }

    final nameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'e.g. prod-db',
    );

    Future<void> open(WidgetTester tester, {bool isReplay = false}) async {
      await tester.pumpWidget(app(isReplay: isReplay));
      await settle(tester);
      await tester.enterText(nameField, 'setup-test');
      await settle(tester);
    }

    testWidgets('is one step: Create, and no step counter', (tester) async {
      await open(tester);
      expect(find.text('Create topic'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.textContaining('Step 1'), findsNothing);
    });

    testWidgets('moves on by itself after the create, once', (tester) async {
      await open(tester);
      await tester.tap(find.text('Create topic'));
      await settle(tester);
      // The picture of Home with the new topic in it takes 1.2 s.
      expect(doneCalls, 0);
      await tester.pump(topicMadeBeatTakes);
      await settle(tester);

      expect(doneCalls, 1);
      expect(getIt<FirstTopicHandoff>().entry?.topicName, 'setup-test');
    });

    testWidgets('never draws the token or the created state', (tester) async {
      await open(tester);
      await tester.tap(find.text('Create topic'));
      // Every frame from the tap to the hand-over.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.textContaining('tk_'), findsNothing);
        expect(find.text('Endpoint and token'), findsNothing);
        expect(find.text('Done'), findsNothing);
      }
      final token = getIt<FirstTopicHandoff>().entry?.token;
      expect(token, isNotNull);
      expect(find.textContaining(token!), findsNothing);
    });

    testWidgets('has no close button', (tester) async {
      await open(tester);

      expect(find.bySemanticsLabel('Not now'), findsNothing);
    });

    testWidgets('a replay moves on and makes nothing', (tester) async {
      await getIt<FirstTopicHandoff>().clear();
      await open(tester, isReplay: true);
      await tester.tap(find.text('Create topic'));
      await settle(tester);

      expect(doneCalls, 1);
      expect(getIt<FirstTopicHandoff>().entry, isNull);
      expect(
        getIt<MockServer>().getTopics().map((topic) => topic.name),
        isNot(contains('setup-test')),
      );
    });
  });
}
