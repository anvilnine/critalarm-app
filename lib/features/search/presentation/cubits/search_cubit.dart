import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/entities/search_scope.dart';
import 'package:critalarm/features/search/domain/query_date.dart';
import 'package:critalarm/features/search/domain/search_ranking.dart';
import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:critalarm/features/search/domain/usecases/add_recent_search_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/clear_recent_searches_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_docs_index_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_recent_searches_usecase.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Everything searchable, loaded once when the screen opens and then ranked in
/// memory on every keystroke.
///
/// There is no debounce. Nothing here touches the network per keystroke, so
/// ranking a few dozen rows is instant and delaying it would only add lag.
class SearchCubit extends Cubit<SearchState> {
  // The private fields below are named parameters at the call site under their
  // public names: `getTopics:`, `getIncidents:`, and so on.
  SearchCubit({
    required this._getTopics,
    required this._getIncidents,
    required this._getDocsIndex,
    required this._getRecentSearches,
    required this._addRecentSearch,
    required this._clearRecentSearches,
    required this._includeDevOnlySettings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SearchState());

  final GetTopicsUsecase _getTopics;
  final GetIncidentsUsecase _getIncidents;
  final GetDocsIndexUsecase _getDocsIndex;
  final GetRecentSearchesUsecase _getRecentSearches;
  final AddRecentSearchUsecase _addRecentSearch;
  final ClearRecentSearchesUsecase _clearRecentSearches;
  final bool _includeDevOnlySettings;
  final DateTime Function() _now;

  /// Every searchable thing, in the order sections should break ties: topics,
  /// past alarms, settings, documentation.
  List<SearchResult> _catalogue = const <SearchResult>[];

  /// Loads the catalogue and the recent searches.
  ///
  /// Settings and documentation are always available, so a failure to read
  /// topics or past alarms narrows the results rather than failing the screen.
  Future<void> load({SearchScope? scope}) async {
    emit(state.copyWith(status: SearchStatus.loading, scope: scope));

    // Started together, awaited one at a time, so all four run at once and
    // each keeps its own type.
    final topicsCall = _getTopics(const NoParams());
    final incidentsCall = _getIncidents(const GetIncidentsParams(limit: 200));
    final docsCall = _getDocsIndex(const NoParams());
    final recentCall = _getRecentSearches(const NoParams());

    final topics = (await topicsCall).getOrNull() ?? const <Topic>[];
    final incidents = (await incidentsCall).getOrNull() ?? const <Incident>[];
    final docs = (await docsCall).getOrNull() ?? const <DocsPage>[];
    final recent = (await recentCall).getOrNull() ?? const <String>[];

    if (isClosed) return;

    _catalogue = <SearchResult>[
      ..._topicResults(topics),
      ..._historyResults(incidents),
      ..._settingsResults(),
      ..._docsResults(docs),
    ];

    emit(
      state.copyWith(
        status: SearchStatus.ready,
        recent: recent,
        results: _rank(state.query),
        clearError: true,
      ),
    );
  }

  /// Re-ranks against the catalogue already in memory.
  void updateQuery(String query) {
    emit(state.copyWith(query: query, results: _rank(query)));
  }

  void clearQuery() => updateQuery('');

  /// Remembers a search the user actually acted on. Called when a result is
  /// tapped, not on every keystroke, so the list holds searches that worked.
  Future<void> recordSearch(String query) async {
    final result = await _addRecentSearch(query);
    final updated = result.getOrNull();
    if (updated != null && !isClosed) {
      emit(state.copyWith(recent: updated));
    }
  }

  Future<void> clearRecent() async {
    await _clearRecentSearches(const NoParams());
    if (!isClosed) emit(state.copyWith(recent: const <String>[]));
  }

  List<SearchResult> _rank(String query) {
    if (query.trim().isEmpty) return const <SearchResult>[];
    return SearchRanking.rank(
      _catalogue,
      query: query,
      scope: state.scope,
      queryDate: QueryDate.parse(query, now: _now()),
    );
  }

  List<SearchResult> _topicResults(List<Topic> topics) {
    return <SearchResult>[
      for (final topic in topics)
        SearchResult(
          kind: SearchResultKind.topic,
          id: topic.name,
          title: topic.name,
          subtitle: topic.critical
              ? LocaleKeys.search_subtitle_topic_critical.tr()
              : LocaleKeys.search_subtitle_topic.tr(),
          keywords: <String>[
            'topic',
            if (topic.critical) 'critical',
          ],
          routePath: '/topics/${Uri.encodeComponent(topic.name)}',
        ),
    ];
  }

  List<SearchResult> _historyResults(List<Incident> incidents) {
    final entries = HistoryCubit.toEntries(incidents, _now());
    final dayFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');

    return <SearchResult>[
      for (final entry in entries)
        SearchResult(
          kind: SearchResultKind.history,
          id: entry.id,
          title: entry.topic,
          subtitle:
              '${dayFormat.format(entry.startedAt)}, '
              '${timeFormat.format(entry.startedAt)}',
          keywords: <String>[
            'history',
            'alarm',
            _stateWord(entry),
            dayFormat.format(entry.startedAt).toLowerCase(),
            DateFormat('MMMM').format(entry.startedAt).toLowerCase(),
            DateFormat('EEEE').format(entry.startedAt).toLowerCase(),
          ],
          routePath: '/incidents/${Uri.encodeComponent(entry.id)}',
          date: entry.day,
        ),
    ];
  }

  static String _stateWord(HistoryEntry entry) => switch (entry.state) {
    IncidentState.open => 'ringing',
    IncidentState.acked => 'acknowledged',
    IncidentState.closed => 'resolved',
    IncidentState.expired => 'expired',
  };

  List<SearchResult> _settingsResults() {
    final destinations = SettingsSearchIndex.forBuild(
      includeDevOnly: _includeDevOnlySettings,
    );
    return <SearchResult>[
      for (final destination in destinations)
        SearchResult(
          kind: SearchResultKind.settings,
          id: destination.id,
          title: destination.titleKey.tr(),
          subtitle: destination.parentTitleKey.tr(),
          keywords: <String>['settings', ...destination.keywords],
          routePath: destination.routePath,
        ),
    ];
  }

  List<SearchResult> _docsResults(List<DocsPage> pages) {
    return <SearchResult>[
      for (final page in pages)
        SearchResult(
          kind: SearchResultKind.docs,
          id: page.slug,
          title: page.title,
          subtitle: page.group,
          keywords: <String>[
            'docs',
            'documentation',
            'how to',
            'help',
            page.description.toLowerCase(),
            page.slug.toLowerCase(),
          ],
          externalUrl: page.url,
        ),
    ];
  }
}
