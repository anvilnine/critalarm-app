import 'dart:async';

import 'package:critalarm/app/state/app_data_status.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hands out list reads and deletes the test finishes by hand.
class _Scripted implements TopicRepository {
  final reads = <Completer<AppResult<List<Topic>>>>[];
  final deletes = <Completer<AppResult<Unit>>>[];

  @override
  Future<AppResult<List<Topic>>> getTopics() {
    final completer = Completer<AppResult<List<Topic>>>();
    reads.add(completer);
    return completer.future;
  }

  @override
  Future<AppResult<Unit>> deleteTopic(String name) {
    final completer = Completer<AppResult<Unit>>();
    deletes.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A store whose reads and writes throw, as a database that will not open
/// does once it is open and then breaks.
class _BrokenTopicStore extends TopicStore {
  _BrokenTopicStore(super._db);

  @override
  Future<List<Topic>?> read(String scope) async => throw StateError('disk');

  @override
  Future<void> replaceAll(String scope, Iterable<Topic> topics) async =>
      throw StateError('disk');
}

String _scopeOf(String account, {String server = 'https://api.example'}) =>
    heldScopeFor(serverUrl: server, accountId: account)!;

const _prod = Topic(name: 'prod-db', critical: true, deskTimerS: 300);
const _nas = Topic(name: 'nas-backup');
const _web = Topic(name: 'web-front');

void main() {
  sqfliteFfiInit();

  late LocalStore store;
  late _Scripted scripted;

  /// The scope the phone is on now. A test changes it to be somebody else.
  late String? scope;

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    scripted = _Scripted();
    scope = _scopeOf('a1');
  });

  tearDown(() async => store.close());

  TopicsCubit build({
    TopicStore? held,
    AccountIdentityChanges? identityChanges,
    Future<String?> Function()? heldScope,
    bool withDelete = false,
  }) {
    final cubit = TopicsCubit(
      GetTopicsUsecase(scripted),
      deleteTopic: withDelete ? DeleteTopicUsecase(scripted) : null,
      held: held ?? store.topics,
      heldScope: heldScope ?? () async => scope,
      identityChanges: identityChanges ?? AccountIdentityChanges(),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<List<Topic>?> stored([String? forScope]) =>
      store.topics.read(forScope ?? scope!);

  group('starting from the list the phone kept', () {
    test('the first state is the stored list, ready, with no wait', () async {
      await store.topics.replaceAll(scope!, [_prod, _nas]);
      final cubit = build();
      expect(cubit.state.status, AppDataStatus.initial);

      await cubit.loadHeld();

      expect(cubit.state.isReady, isTrue);
      expect(cubit.state.isKept, isTrue);
      expect(cubit.state.topics, [_prod, _nas]);
      expect(cubit.state.isRefreshing, isFalse);
      expect(cubit.state.errorMessage, isNull);
      // Nothing went to the server to get it.
      expect(scripted.reads, isEmpty);
    });

    test(
      'Critical delivery and the timers come from the stored list',
      () async {
        await store.topics.replaceAll(scope!, [_prod]);
        final cubit = build();

        await cubit.loadHeld();

        final topic = cubit.state.named('prod-db')!;
        expect(topic.critical, isTrue);
        expect(topic.deskTimerS, 300);
      },
    );

    test('a list the phone kept still goes to the server once', () async {
      await store.topics.replaceAll(scope!, [_prod]);
      final cubit = build();
      await cubit.loadHeld();

      final load = cubit.ensureLoaded();
      await pumpEventQueue();
      expect(scripted.reads, hasLength(1));
      expect(cubit.state.isRefreshing, isTrue);
      // The stored list stays on screen while the request is in the air.
      expect(cubit.state.topics, [_prod]);
      expect(cubit.state.isReady, isTrue);

      scripted.reads[0].complete([_prod].toSuccess());
      await load;
      expect(cubit.state.isKept, isFalse);

      // Now it is a load like any other.
      await cubit.ensureLoaded();
      expect(scripted.reads, hasLength(1));
      await cubit.writesDone;
    });

    test('the server answer replaces the stored list', () async {
      await store.topics.replaceAll(scope!, [_prod, _nas]);
      final cubit = build();
      await cubit.loadHeld();

      final load = cubit.ensureLoaded();
      await pumpEventQueue();
      scripted.reads[0].complete(
        [const Topic(name: 'prod-db'), _web].toSuccess(),
      );
      await load;

      expect(cubit.state.isKept, isFalse);
      expect(cubit.state.status, AppDataStatus.ready);
      expect(cubit.state.topics.map((t) => t.name), ['prod-db', 'web-front']);
      // Critical was switched off elsewhere. The server's word wins.
      expect(cubit.state.named('prod-db')!.critical, isFalse);
      await cubit.writesDone;
      expect((await stored())!.map((t) => t.name), ['prod-db', 'web-front']);
    });

    test('a topic deleted on the server is gone after the refresh', () async {
      await store.topics.replaceAll(scope!, [_prod, _nas, _web]);
      final cubit = build();
      await cubit.loadHeld();
      expect(cubit.state.named('nas-backup'), isNotNull);

      final load = cubit.refresh();
      scripted.reads[0].complete([_prod, _web].toSuccess());
      await load;

      expect(cubit.state.named('nas-backup'), isNull);
      await cubit.writesDone;
      expect((await stored())!.map((t) => t.name), ['prod-db', 'web-front']);
    });

    test('an empty answer from the server empties the stored list', () async {
      await store.topics.replaceAll(scope!, [_prod]);
      final cubit = build();
      await cubit.loadHeld();

      final load = cubit.refresh();
      scripted.reads[0].complete(<Topic>[].toSuccess());
      await load;

      expect(cubit.state.topics, isEmpty);
      expect(cubit.state.isReady, isTrue);
      await cubit.writesDone;
      expect(await stored(), isNull);
    });

    test(
      'a failed refresh keeps the stored list and reports the error',
      () async {
        await store.topics.replaceAll(scope!, [_prod, _nas]);
        final cubit = build();
        await cubit.loadHeld();

        final load = cubit.refresh();
        scripted.reads[0].complete(
          const Failure.api(statusCode: 500).toFailure(),
        );
        await load;

        expect(cubit.state.topics, [_prod, _nas]);
        expect(cubit.state.status, AppDataStatus.failure);
        expect(cubit.state.errorMessage, isNotNull);
        expect(cubit.state.isRefreshing, isFalse);
        // Still the phone's copy, not confirmed by anyone.
        expect(cubit.state.isKept, isTrue);
        await cubit.writesDone;
        expect(await stored(), [_prod, _nas]);
      },
    );

    test('a refresh that works after a failed one clears the error', () async {
      await store.topics.replaceAll(scope!, [_prod]);
      final cubit = build();
      await cubit.loadHeld();
      final failed = cubit.refresh();
      scripted.reads[0].complete(
        const Failure.api(statusCode: 500).toFailure(),
      );
      await failed;

      final again = cubit.ensureLoaded();
      await pumpEventQueue();
      scripted.reads[1].complete([_prod, _web].toSuccess());
      await again;

      expect(cubit.state.status, AppDataStatus.ready);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isKept, isFalse);
      expect(cubit.state.topics, hasLength(2));
      await cubit.writesDone;
    });

    test(
      'a server answer that lands first is not replaced by the copy',
      () async {
        await store.topics.replaceAll(scope!, [_prod]);
        final cubit = build();

        final load = cubit.refresh();
        scripted.reads[0].complete([_prod, _web].toSuccess());
        await load;
        await cubit.loadHeld();

        expect(cubit.state.isKept, isFalse);
        expect(cubit.state.topics, hasLength(2));
      },
    );
  });

  group('when the phone holds nothing it can use', () {
    test('nothing held leaves the state as it was', () async {
      final cubit = build();

      await cubit.loadHeld();

      expect(cubit.state.status, AppDataStatus.initial);
      expect(cubit.state.topics, isEmpty);
      expect(cubit.state.isKept, isFalse);
    });

    test('no server saved means no scope, so nothing is read', () async {
      await store.topics.replaceAll(_scopeOf('a1'), [_prod]);
      scope = null;
      final cubit = build();

      await cubit.loadHeld();

      expect(cubit.state.status, AppDataStatus.initial);
    });

    test('an unreadable store falls back to loading from the server', () async {
      final cubit = build(held: _BrokenTopicStore(store.db));

      await cubit.loadHeld();

      expect(cubit.state.status, AppDataStatus.initial);
      expect(cubit.state.isKept, isFalse);

      // And the list loads as it always did.
      final load = cubit.ensureLoaded();
      scripted.reads[0].complete([_prod].toSuccess());
      await load;
      expect(cubit.state.topics, [_prod]);
      expect(cubit.state.isReady, isTrue);
      // A write that fails is swallowed too.
      await cubit.writesDone;
    });

    test('a scope that cannot be read is no scope', () async {
      await store.topics.replaceAll(_scopeOf('a1'), [_prod]);
      final cubit = build(heldScope: () async => throw StateError('keychain'));

      await cubit.loadHeld();

      expect(cubit.state.status, AppDataStatus.initial);
    });

    test("no store at all is today's behaviour", () async {
      final cubit = TopicsCubit(
        GetTopicsUsecase(scripted),
        identityChanges: AccountIdentityChanges(),
      );
      addTearDown(cubit.close);

      await cubit.loadHeld();
      expect(cubit.state.status, AppDataStatus.initial);

      final load = cubit.ensureLoaded();
      scripted.reads[0].complete([_prod].toSuccess());
      await load;
      expect(cubit.state.topics, [_prod]);
      await cubit.writesDone;
      expect(await store.topics.count(), 0);
    });
  });

  group('a list belongs to one server and one account', () {
    test('another account on the same server is not shown', () async {
      await store.topics.replaceAll(_scopeOf('a1'), [_prod]);
      scope = _scopeOf('a2');
      final cubit = build();

      await cubit.loadHeld();

      expect(cubit.state.status, AppDataStatus.initial);
      expect(cubit.state.topics, isEmpty);
      // And what was held for the other account is gone from the phone.
      expect(await store.topics.count(), 0);
    });

    test('the same account on another server is not shown', () async {
      await store.topics.replaceAll(_scopeOf('a1'), [_prod]);
      scope = _scopeOf('a1', server: 'https://other.example');
      final cubit = build();

      await cubit.loadHeld();

      expect(cubit.state.status, AppDataStatus.initial);
      expect(cubit.state.topics, isEmpty);
    });

    test('a sign-out and a new account: the next list is kept for the new '
        'account only', () async {
      await store.topics.replaceAll(_scopeOf('a1'), [_prod]);
      final cubit = build();
      await cubit.loadHeld();

      // Signed out: the account on the phone is somebody new.
      scope = _scopeOf('fresh');
      final load = cubit.refresh();
      scripted.reads[0].complete(<Topic>[_web].toSuccess());
      await load;
      await cubit.writesDone;

      expect((await stored(_scopeOf('fresh')))!.single.name, 'web-front');
      expect(await stored(_scopeOf('a1')), isNull);
    });

    test('an answer for an account that was left in flight is shown as it '
        'was but never written under the next account', () async {
      final changes = AccountIdentityChanges();
      final cubit = build(identityChanges: changes);
      final load = cubit.refresh();
      await pumpEventQueue();

      // The user signs out while the request is in the air. The new account
      // has a scope of its own by the time the old answer lands.
      scope = _scopeOf('fresh');
      changes.bump();
      scripted.reads[0].complete([_prod].toSuccess());
      await load;
      await cubit.writesDone;

      expect(await store.topics.count(), 0);
    });

    test('an answer is not written when the scope moved before it landed '
        'even with no identity bump', () async {
      final cubit = build();
      final load = cubit.refresh();
      await pumpEventQueue();

      scope = _scopeOf('a2');
      scripted.reads[0].complete([_prod].toSuccess());
      await load;
      await cubit.writesDone;

      expect(await store.topics.count(), 0);
    });

    test('with no scope nothing is written', () async {
      scope = null;
      final cubit = build();

      final load = cubit.refresh();
      scripted.reads[0].complete([_prod].toSuccess());
      await load;
      await cubit.writesDone;

      expect(cubit.state.topics, [_prod]);
      expect(await store.topics.count(), 0);
    });

    test('clearing the archive for a new server takes the list too', () async {
      await store.topics.replaceAll(scope!, [_prod]);

      await store.clearServerData();

      final cubit = build();
      await cubit.loadHeld();
      expect(cubit.state.status, AppDataStatus.initial);
    });
  });

  group('every change to the list is written to the phone', () {
    Future<TopicsCubit> loaded({List<Topic>? answer}) async {
      final cubit = build(withDelete: true);
      final load = cubit.ensureLoaded();
      scripted.reads[0].complete((answer ?? [_prod, _nas, _web]).toSuccess());
      await load;
      await cubit.writesDone;
      return cubit;
    }

    test('the refresh', () async {
      await loaded();
      expect((await stored())!.map((t) => t.name), [
        'prod-db',
        'nas-backup',
        'web-front',
      ]);
    });

    test('the Critical switch', () async {
      final cubit = await loaded();

      cubit.applyTopic(_nas.copyWith(critical: true));
      await cubit.writesDone;

      final back = await stored();
      expect(back!.firstWhere((t) => t.name == 'nas-backup').critical, isTrue);
      expect(back, hasLength(3));
    });

    test('other settings of a topic', () async {
      final cubit = await loaded();

      cubit.applyTopic(
        _prod.copyWith(repeatIntervalS: 60, maxRingS: 600, deskTimerS: 120),
      );
      await cubit.writesDone;

      final back = (await stored())!.first;
      expect(back.repeatIntervalS, 60);
      expect(back.maxRingS, 600);
      expect(back.deskTimerS, 120);
    });

    test('a delete the server took', () async {
      final cubit = await loaded();

      final delete = cubit.deleteTopic('nas-backup');
      await pumpEventQueue();
      scripted.deletes[0].complete(unit.toSuccess());
      expect(await delete, isNull);
      await cubit.writesDone;

      expect((await stored())!.map((t) => t.name), [
        'prod-db',
        'web-front',
      ]);
    });

    test('a delete the server refused leaves the stored list whole', () async {
      final cubit = await loaded();

      final delete = cubit.deleteTopic('nas-backup');
      await pumpEventQueue();
      // In the air: the list on screen lost it, the phone's copy has not.
      await cubit.writesDone;
      expect(await stored(), hasLength(3));
      scripted.deletes[0].complete(
        const Failure.api(statusCode: 500).toFailure(),
      );
      expect(await delete, isNotNull);
      await cubit.writesDone;

      expect(await stored(), hasLength(3));
      expect(cubit.state.topics, hasLength(3));
    });

    test('a topic just created, without its token', () async {
      final cubit = await loaded(answer: [_prod]);

      cubit.noteCreated(
        const Topic(
          name: 'new-one',
          token: 'tk_secret',
          tokenId: 'tok_1',
          tokenName: 'CI',
        ),
      );
      await cubit.writesDone;

      final back = (await stored())!;
      expect(back.map((t) => t.name), ['prod-db', 'new-one']);
      expect(back.last.token, isNull);
      expect(back.last.tokenId, isNull);
      expect(back.last.tokenName, isNull);
      // The list on screen is left to the next refresh.
      expect(cubit.state.topics.map((t) => t.name), ['prod-db']);
    });

    test('a topic created before any list was loaded writes nothing, so the '
        'copy never holds one topic as if it were all', () async {
      await store.topics.replaceAll(scope!, [_prod, _nas]);
      final cubit = build()..noteCreated(_web);
      await cubit.writesDone;

      expect((await stored())!.map((t) => t.name), ['prod-db', 'nas-backup']);
    });

    test(
      'a switch applied before any list was loaded writes nothing',
      () async {
        await store.topics.replaceAll(scope!, [_prod, _nas]);
        final cubit = build()..applyTopic(_web);
        await cubit.writesDone;

        expect((await stored())!.map((t) => t.name), ['prod-db', 'nas-backup']);
      },
    );

    test('a switch applied on the held list is kept with the rest', () async {
      await store.topics.replaceAll(scope!, [_prod, _nas]);
      final cubit = build();
      await cubit.loadHeld();

      cubit.applyTopic(_nas.copyWith(critical: true));
      await cubit.writesDone;

      final back = (await stored())!;
      expect(back.map((t) => t.name), ['prod-db', 'nas-backup']);
      expect(back.last.critical, isTrue);
    });

    test('writes land in the order they were made', () async {
      final cubit = await loaded();

      cubit
        ..applyTopic(_nas.copyWith(critical: true))
        ..applyTopic(_nas.copyWith(deskTimerS: 5));
      await cubit.writesDone;

      final back = (await stored())!.firstWhere((t) => t.name == _nas.name);
      expect(back.deskTimerS, 5);
      // The second apply came from a copy with Critical off.
      expect(back.critical, isFalse);
    });
  });
}
