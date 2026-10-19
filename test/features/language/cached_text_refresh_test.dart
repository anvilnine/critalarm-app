import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void translateErrors(String text) => Localization.load(
  const Locale('en'),
  translations: Translations({
    'api_errors': {'unknown': text},
  }),
);

class _Topics implements TopicRepository {
  int reads = 0;
  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    reads++;
    return const Failure.unexpected().toFailure();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Incidents implements IncidentRepository {
  int reads = 0;
  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? topic,
    String? state,
    DateTime? since,
    bool fullRefresh = false,
  }) async {
    reads++;
    return const Failure.unexpected().toFailure();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('Topics refresh changes error text only, without refetching', () async {
    translateErrors('old error');
    final repository = _Topics();
    final cubit = TopicsCubit(GetTopicsUsecase(repository));
    await cubit.refresh();
    final before = cubit.state;
    expect(before.errorMessage, 'old error');
    translateErrors('new error');
    cubit.refreshTranslations();
    expect(cubit.state.errorMessage, 'new error');
    expect(cubit.state.status, before.status);
    expect(identical(cubit.state.topics, before.topics), isTrue);
    expect(cubit.state.isRefreshing, before.isRefreshing);
    expect(repository.reads, 1);
    await cubit.close();
  });

  test(
    'Incidents refresh changes error text only, without refetching',
    () async {
      translateErrors('old error');
      final repository = _Incidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(repository));
      await cubit.refresh();
      final before = cubit.state;
      expect(before.errorMessage, 'old error');
      translateErrors('new error');
      cubit.refreshTranslations();
      expect(cubit.state.errorMessage, 'new error');
      expect(cubit.state.status, before.status);
      expect(identical(cubit.state.incidents, before.incidents), isTrue);
      expect(cubit.state.isRefreshing, before.isRefreshing);
      expect(repository.reads, 1);
      await cubit.close();
    },
  );
}
