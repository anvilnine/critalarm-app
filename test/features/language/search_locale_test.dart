import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:critalarm/features/search/domain/repositories/docs_index_repository.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/usecases/add_recent_search_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/clear_recent_searches_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_docs_index_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_recent_searches_usecase.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Topics implements TopicRepository {
  int reads = 0;
  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    reads++;
    return <Topic>[const Topic(name: 'prod')].toSuccess();
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
    return <Incident>[].toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Docs implements DocsIndexRepository {
  int reads = 0;
  @override
  Future<AppResult<List<DocsPage>>> getPages() async {
    reads++;
    return <DocsPage>[].toSuccess();
  }
}

class _Recent implements RecentSearchesRepository {
  @override
  Future<AppResult<List<String>>> getRecent() async => ['prod'].toSuccess();
  @override
  Future<AppResult<List<String>>> add(String query) async =>
      [query].toSuccess();
  @override
  Future<AppResult<Unit>> clear() async => unit.toSuccess();
}

void _translate(String prefix) => Localization.load(
  const Locale('en'),
  translations: Translations({
    'search': {'subtitle_topic': '$prefix topic'},
    'reliability': {'title': '$prefix health'},
    'nav': {'settings': '$prefix settings'},
  }),
);

void main() {
  test(
    'shell-held search rebuilds cached translations, '
    'no refetch, no lost query',
    () async {
      await initializeDateFormatting();
      _translate('old');
      final changes = StreamController<void>.broadcast(sync: true);
      final topicRepo = _Topics();
      final incidentRepo = _Incidents();
      final docs = _Docs();
      final recent = _Recent();
      final topics = TopicsCubit(GetTopicsUsecase(topicRepo));
      final incidents = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
      final cubit = SearchCubit(
        topics: topics,
        incidents: incidents,
        getDocsIndex: GetDocsIndexUsecase(docs),
        getRecentSearches: GetRecentSearchesUsecase(recent),
        addRecentSearch: AddRecentSearchUsecase(recent),
        clearRecentSearches: ClearRecentSearchesUsecase(recent),
        includeDevOnlySettings: false,
        localeChanges: changes.stream,
      );
      await cubit.load();
      cubit.updateQuery('prod');
      expect(cubit.state.results.single.subtitle, 'old topic');
      _translate('new');
      changes.add(null);
      expect(cubit.state.query, 'prod');
      expect(cubit.state.recent, ['prod']);
      expect(cubit.state.results.single.subtitle, 'new topic');
      cubit.updateQuery('health');
      final health = cubit.state.results.firstWhere(
        (result) => result.id == 'reliability',
      );
      expect(health.title, 'new health');
      expect(health.subtitle, 'new settings');
      expect([topicRepo.reads, incidentRepo.reads, docs.reads], [1, 1, 1]);
      await cubit.close();
      changes.add(null);
      await topics.close();
      await incidents.close();
      await changes.close();
    },
  );
}
