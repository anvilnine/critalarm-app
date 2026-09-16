import 'dart:async';

import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out a list read the test finishes by hand, so one can still be in the
/// air while the user changes something.
class _ScriptedTopics implements TopicRepository {
  final pending = <Completer<AppResult<List<Topic>>>>[];

  @override
  Future<AppResult<List<Topic>>> getTopics() {
    final completer = Completer<AppResult<List<Topic>>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Topic _topic({bool critical = false}) =>
    Topic(name: 'prod-db', critical: critical);

void main() {
  group('the stale-write guard', () {
    test(
      'a list read asked for before the switch was flipped is dropped',
      () async {
        final scripted = _ScriptedTopics();
        var clock = DateTime(2026, 9, 17, 9);
        final cubit = TopicsCubit(GetTopicsUsecase(scripted), now: () => clock);
        addTearDown(cubit.close);

        final first = cubit.ensureLoaded();
        scripted.pending[0].complete([_topic()].toSuccess());
        await first;
        expect(cubit.state.topics.single.critical, isFalse);

        // A slow list read goes out, then the user switches critical delivery
        // on and the server confirms it.
        clock = DateTime(2026, 9, 17, 9, 0, 1);
        final slow = cubit.refresh();
        clock = DateTime(2026, 9, 17, 9, 0, 2);
        cubit.applyTopic(_topic(critical: true));

        // The slow answer still has the switch off. It is older than the
        // change, so it must not put the toggle back.
        scripted.pending[1].complete([_topic()].toSuccess());
        await slow;

        expect(cubit.state.topics.single.critical, isTrue);
        expect(cubit.state.isRefreshing, isFalse);
      },
    );

    test(
      'a list read asked for after the switch was flipped is kept',
      () async {
        final scripted = _ScriptedTopics();
        var clock = DateTime(2026, 9, 17, 9);
        final cubit = TopicsCubit(GetTopicsUsecase(scripted), now: () => clock);
        addTearDown(cubit.close);

        final first = cubit.ensureLoaded();
        scripted.pending[0].complete([_topic()].toSuccess());
        await first;

        cubit.applyTopic(_topic(critical: true));
        clock = DateTime(2026, 9, 17, 9, 0, 5);
        final second = cubit.refresh();
        scripted.pending[1].complete(
          [
            const Topic(name: 'nas-backup'),
          ].toSuccess(),
        );
        await second;

        expect(cubit.state.topics.single.name, 'nas-backup');
      },
    );
  });
}
