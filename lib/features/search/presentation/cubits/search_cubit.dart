import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
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
    required this._topics,
    required this._incidents,
    required this._getDocsIndex,
    required this._getRecentSearches,
    required this._addRecentSearch,
    required this._clearRecentSearches,
    required this._includeDevOnlySettings,
    this.identityStore,
    this.sessionStore,
    PlanChanges? planChanges,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _planChanges = planChanges ?? appPlanChanges,
       super(const SearchState()) {
    _planChanges.addListener(_onPlanChanged);
  }

  final TopicsCubit _topics;
  final IncidentsCubit _incidents;
  final GetDocsIndexUsecase _getDocsIndex;
  final GetRecentSearchesUsecase _getRecentSearches;
  final AddRecentSearchUsecase _addRecentSearch;
  final ClearRecentSearchesUsecase _clearRecentSearches;
  final bool _includeDevOnlySettings;
  final DateTime Function() _now;

  /// Read to decide whether the Storage rows exist in Settings. Null in
  /// tests, and then only the store or the developer switch can say paid.
  final DeviceIdentityStore? identityStore;

  /// Says whether the server is self-hosted, which also shows Storage.
  final ApiSessionStore? sessionStore;

  /// Moves when a purchase lands, so Storage becomes searchable right away.
  final PlanChanges _planChanges;

  /// Whether Settings draws its Storage section. Same rule as
  /// `SettingsState.hasStorageSection`.
  bool _showsStorage = false;

  Future<bool> _readShowsStorage() async {
    final identity = await identityStore?.readOrCreate();
    final session = await sessionStore?.read();
    return AccountAccess(identity, planChanges: _planChanges).isPaid ||
        session?.mode == ServerMode.selfhosted;
  }

  void _onPlanChanged() {
    if (isClosed || state.status != SearchStatus.ready) return;
    unawaited(_refreshStorage());
  }

  Future<void> _refreshStorage() async {
    final shows = await _readShowsStorage();
    if (isClosed || shows == _showsStorage) return;
    _showsStorage = shows;
    _catalogue = _buildCatalogue();
    emit(state.copyWith(results: _rank(state.query)));
  }

  /// Every searchable thing, in the order sections should break ties: topics,
  /// past alarms, settings, documentation.
  List<SearchResult> _catalogue = const <SearchResult>[];

  /// The documentation index, read once. It ships with the app, so nothing
  /// changes it while search is open.
  List<DocsPage> _docs = const <DocsPage>[];

  StreamSubscription<IncidentsState>? _incidentsSub;
  StreamSubscription<TopicsState>? _topicsSub;

  /// The lists the catalogue was built from.
  List<Incident>? _seenIncidents;
  List<Topic>? _seenTopics;

  /// Loads the catalogue and the recent searches.
  ///
  /// Settings and documentation are always available, so a failure to read
  /// topics or past alarms narrows the results rather than failing the screen.
  /// Topics and past alarms come from the app-level cubits, so opening search
  /// does not fetch what another screen already has.
  Future<void> load({SearchScope? scope}) async {
    emit(state.copyWith(status: SearchStatus.loading, scope: scope));

    _incidentsSub ??= _incidents.stream.listen((_) => _rebuildCatalogue());
    _topicsSub ??= _topics.stream.listen((_) => _rebuildCatalogue());

    // Started together, awaited one at a time, so all four run at once and
    // each keeps its own type.
    final topicsCall = _topics.ensureLoaded();
    final incidentsCall = _incidents.ensureLoaded();
    final docsCall = _getDocsIndex(const NoParams());
    final recentCall = _getRecentSearches(const NoParams());

    await topicsCall;
    await incidentsCall;
    _docs = (await docsCall).getOrNull() ?? const <DocsPage>[];
    final recent = (await recentCall).getOrNull() ?? const <String>[];
    _showsStorage = await _readShowsStorage();

    if (isClosed) return;

    _catalogue = _buildCatalogue();
    _seenIncidents = _incidents.state.incidents;
    _seenTopics = _topics.state.topics;

    emit(
      state.copyWith(
        status: SearchStatus.ready,
        recent: recent,
        results: _rank(state.query),
        clearError: true,
      ),
    );
  }

  /// A topic created or an alarm acknowledged elsewhere changes what search
  /// should find, so the catalogue is rebuilt in place.
  void _rebuildCatalogue() {
    if (isClosed || state.status != SearchStatus.ready) return;
    final incidents = _incidents.state.incidents;
    final topics = _topics.state.topics;
    if (identical(incidents, _seenIncidents) &&
        identical(topics, _seenTopics)) {
      return;
    }
    _seenIncidents = incidents;
    _seenTopics = topics;
    _catalogue = _buildCatalogue();
    emit(state.copyWith(results: _rank(state.query)));
  }

  List<SearchResult> _buildCatalogue() {
    final topics = _topics.state.topics;
    final incidents = _incidents.state.incidents;

    // Which topics are ringing right now, so a topic result wears the same
    // face it wears on the Topics list.
    final ringing = <String>{
      for (final incident in incidents)
        if (incident.isOpen) incident.topic,
    };

    return <SearchResult>[
      ..._topicResults(topics, ringing),
      ..._historyResults(incidents),
      ..._settingsResults(),
      ..._docsResults(_docs),
    ];
  }

  @override
  Future<void> close() async {
    _planChanges.removeListener(_onPlanChanged);
    await _incidentsSub?.cancel();
    await _topicsSub?.cancel();
    return super.close();
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

  List<SearchResult> _topicResults(List<Topic> topics, Set<String> ringing) {
    return <SearchResult>[
      for (final topic in topics)
        SearchResult(
          kind: SearchResultKind.topic,
          id: topic.name,
          title: topic.name,
          subtitle: topic.critical
              ? LocaleKeys.search_subtitle_topic_critical.tr()
              : LocaleKeys.search_subtitle_topic.tr(),
          keywords: <String>['topic', if (topic.critical) 'critical'],
          routePath: '/topics/${Uri.encodeComponent(topic.name)}',
          faceState: ringing.contains(topic.name)
              ? FaceState.alarmed
              : FaceState.calm,
          isCrit: topic.critical && ringing.contains(topic.name),
        ),
    ];
  }

  List<SearchResult> _historyResults(List<Incident> incidents) {
    final entries = HistoryCubit.toEntries(incidents, _now());
    final dayFormat = DateFormat('MMM d');

    return <SearchResult>[
      for (final entry in entries)
        SearchResult(
          kind: SearchResultKind.history,
          id: entry.id,
          // The same sentence the History list shows, so the row reads the
          // same in both places. The day goes where History puts the time,
          // because a flat result list has no day headings to sit under.
          title: entry.topic,
          subtitle: historyMetaText(entry),
          timeText: dayFormat.format(entry.startedAt),
          faceState: entry.faceState,
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
      showsStorage: _showsStorage,
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
