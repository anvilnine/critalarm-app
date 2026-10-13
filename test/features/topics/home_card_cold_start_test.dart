import 'dart:async';

import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart'
    show MissedFact;
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/held_topics.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain/home_card/home_card_fixtures.dart'
    show androidChecks, setupAfterServer, setupFirstMessageOpen;

/// What a phone does on a cold start after setup: the app has just opened, the
/// topic list is read from the phone before the first frame, and the server has
/// not answered anything yet. The card's first model is the one the user sees.

class _Home extends Cubit<HomeState> {
  _Home() : super(const HomeState());

  void set(HomeState next) => emit(next);
}

class _Setup extends Cubit<HomeSetupState> {
  _Setup() : super(const HomeSetupState());

  void set(HomeSetupState next) => emit(next);
}

class _NoMissed implements MissedAlarmFeed {
  @override
  Future<MissedFact?> read() async => null;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> dismiss(Iterable<String> incidentIds) async {}
}

class _Use implements SetupUseStore {
  @override
  SetupUse? read() => SetupUse.servers;

  @override
  Future<void> save(SetupUse use) async {}

  @override
  Future<void> clear() async {}
}

class _Tools implements ToolTemplateStore {
  @override
  ToolTemplate? read(String topicName) => null;

  @override
  Future<void> save(String topicName, ToolTemplate template) async {}
}

class _Checks implements ReliabilityCheckSource {
  @override
  Future<List<ReliabilityCheck>> read() async => androidChecks(7);
}

/// A server that never answers within the test, as one that is slow to wake.
class _SilentTopics implements TopicRepository {
  final reads = <Completer<AppResult<List<Topic>>>>[];

  @override
  Future<AppResult<List<Topic>>> getTopics() {
    final completer = Completer<AppResult<List<Topic>>>();
    reads.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  sqfliteFfiInit();

  final scope = heldScopeFor(
    serverUrl: 'https://api.example',
    accountId: 'a1',
  )!;
  late LocalStore store;
  late _SilentTopics server;

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    server = _SilentTopics();
  });

  tearDown(() async => store.close());

  /// A cold start: a new cubit, the phone's list read, then Home's card built
  /// with the flags saying setup waits on the first message.
  Future<
    ({
      TopicsCubit topics,
      HomeCardCubit card,
      _Home home,
      _Setup setup,
      List<HomeCardModel> models,
    })
  >
  coldStart() async {
    final topics = TopicsCubit(
      GetTopicsUsecase(server),
      held: store.topics,
      heldScope: () async => scope,
      identityChanges: AccountIdentityChanges(),
    );
    addTearDown(topics.close);
    await topics.loadHeld();

    final home = _Home();
    final setup = _Setup();
    final reliability = ReliabilityCubit([_Checks()]);
    final card = HomeCardCubit(
      home: home,
      reliability: reliability,
      setup: setup,
      missed: _NoMissed(),
      setupUse: _Use(),
      toolTemplates: _Tools(),
      testRouteName: 'testRing',
      askPermissionsRouteName: 'askPermissions',
      isSetupOpen: () => true,
      readHeldTopics: () => heldTopicsFrom(topics.state),
    );
    addTearDown(() async {
      await card.close();
      await reliability.close();
      await home.close();
      await setup.close();
    });
    final models = <HomeCardModel>[card.state.model];
    final sub = card.stream.listen((s) => models.add(s.model));
    addTearDown(sub.cancel);
    return (
      topics: topics,
      card: card,
      home: home,
      setup: setup,
      models: models,
    );
  }

  test('a first topic with Critical off starts on the setup card', () async {
    await store.topics.replaceAll(scope, [const Topic(name: 'prod-db')]);

    final cold = await coldStart();

    final first = cold.models.single;
    expect(first.kind, HomeCardKind.setup);
    expect(first.action, const ContinueSetup('/topics/prod-db'));
    expect(first.action, isNot(isA<GetFirstLine>()));

    // The server answers and agrees: the card never changes.
    cold.home.set(
      HomeState(
        status: HomeStatus.success,
        topicItems: const [HomeTopicItem(name: 'prod-db')],
        lastKnownGoodAt: DateTime.utc(2026, 10, 13),
      ),
    );
    cold.setup.set(
      const HomeSetupState(
        phase: HomeSetupPhase.checklist,
        checklist: setupAfterServer,
        firstTopic: 'prod-db',
        watchedTopic: 'prod-db',
      ),
    );
    await pumpEventQueue();
    expect(cold.card.state.model.kind, HomeCardKind.setup);
    for (final model in cold.models) {
      expect(model.kind, HomeCardKind.setup);
    }
  });

  test('a first topic with Critical on starts on the waiting card', () async {
    await store.topics.replaceAll(scope, [
      const Topic(name: 'prod-db', critical: true),
    ]);

    final cold = await coldStart();

    final first = cold.models.single;
    expect(first.kind, HomeCardKind.waiting);
    expect(first.action, const GetFirstLine('prod-db'));

    cold.home.set(
      HomeState(
        status: HomeStatus.success,
        topicItems: const [
          HomeTopicItem(name: 'prod-db', ringsThroughSilent: true),
        ],
        lastKnownGoodAt: DateTime.utc(2026, 10, 13),
      ),
    );
    cold.setup.set(
      const HomeSetupState(
        phase: HomeSetupPhase.checklist,
        checklist: setupFirstMessageOpen,
        firstTopic: 'prod-db',
        watchedTopic: 'prod-db',
      ),
    );
    await pumpEventQueue();
    for (final model in cold.models) {
      expect(model.kind, HomeCardKind.waiting);
    }
  });

  test('nothing held keeps the waiting guess the card made before', () async {
    final cold = await coldStart();

    expect(cold.topics.state.isReady, isFalse);
    expect(cold.models.single.kind, HomeCardKind.waiting);
  });

  test('a list held for another account is not a guess', () async {
    await store.topics.replaceAll(
      heldScopeFor(serverUrl: 'https://api.example', accountId: 'a2')!,
      [const Topic(name: 'theirs')],
    );

    final cold = await coldStart();

    expect(cold.topics.state.topics, isEmpty);
    expect(cold.models.single.kind, HomeCardKind.waiting);
    expect(cold.models.single.action, isNot(const GetFirstLine('theirs')));
  });

  test('a store that cannot be read leaves the guess as it was', () async {
    await store.db.execute('DROP TABLE topics');

    final cold = await coldStart();

    expect(cold.topics.state.isReady, isFalse);
    expect(cold.models.single.kind, HomeCardKind.waiting);
  });

  test(
    'the list is held in memory the moment it is read, with no request',
    () async {
      await store.topics.replaceAll(scope, [const Topic(name: 'prod-db')]);

      final cold = await coldStart();

      expect(server.reads, isEmpty);
      expect(heldTopicsFrom(cold.topics.state), [
        (name: 'prod-db', isCritical: false),
      ]);
    },
  );
}
