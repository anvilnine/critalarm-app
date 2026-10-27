import 'dart:async';

import 'package:critalarm/app/state/critical_topic_count.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out list reads the test finishes by hand.
class _Scripted implements TopicRepository {
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

const _prod = Topic(name: 'prod-db', critical: true, deskTimerS: 300);
const _nas = Topic(name: 'nas-backup', critical: true, deskTimerS: 300);
const _web = Topic(name: 'web-front');

void main() {
  const wait = Duration(milliseconds: 50);
  late _Scripted scripted;
  late TopicsCubit topics;

  setUp(() {
    scripted = _Scripted();
    topics = TopicsCubit(
      GetTopicsUsecase(scripted),
      identityChanges: AccountIdentityChanges(),
    );
    addTearDown(topics.close);
  });

  /// Loads the list so it is ready.
  Future<void> loadReady(List<Topic> list) async {
    final load = topics.refresh();
    await pumpEventQueue();
    scripted.reads.last.complete(list.toSuccess());
    await load;
    expect(topics.state.isReady, isTrue);
  }

  group('a list that is ready', () {
    test('counts the critical topics and asks the server nothing', () async {
      await loadReady([_prod, _web, _nas]);
      final asked = scripted.reads.length;

      expect(await readCriticalTopicCount(topics, wait: wait), 2);
      expect(scripted.reads, hasLength(asked));
    });

    test('with none critical the count is zero', () async {
      await loadReady([_web]);
      expect(await readCriticalTopicCount(topics, wait: wait), 0);
    });
  });

  group('a list that is refreshing', () {
    test('waits for the answer and counts that one', () async {
      await loadReady([_prod, _web]);
      final refresh = topics.refresh();
      await pumpEventQueue();
      expect(topics.state.isRefreshing, isTrue);

      final count = readCriticalTopicCount(
        topics,
        wait: const Duration(seconds: 5),
      );
      await pumpEventQueue();
      // The one request in the air is shared, not a second one.
      expect(scripted.reads, hasLength(2));
      scripted.reads.last.complete([_prod, _nas, _web].toSuccess());
      await refresh;

      expect(await count, 2);
    });

    test('an answer that does not come in time is not a count', () async {
      await loadReady([_prod]);
      unawaited(topics.refresh());
      await pumpEventQueue();

      await expectLater(
        readCriticalTopicCount(topics, wait: wait),
        throwsStateError,
      );
    });
  });

  group('a list that is not ready', () {
    test('a list never read, with no answer in time, throws', () async {
      await expectLater(
        readCriticalTopicCount(topics, wait: wait),
        throwsStateError,
      );
    });

    test('a read that fails throws', () async {
      final count = readCriticalTopicCount(
        topics,
        wait: const Duration(seconds: 5),
      );
      await pumpEventQueue();
      scripted.reads.single.complete(
        const Failure.api(statusCode: 500).toFailure(),
      );

      await expectLater(count, throwsStateError);
    });

    test('a list that is read in time is counted', () async {
      final count = readCriticalTopicCount(
        topics,
        wait: const Duration(seconds: 5),
      );
      await pumpEventQueue();
      scripted.reads.single.complete([_prod, _nas].toSuccess());

      expect(await count, 2);
    });
  });
}
