import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/entities/search_scope.dart';
import 'package:critalarm/features/search/domain/search_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

SearchResult _result(
  SearchResultKind kind,
  String title, {
  String subtitle = '',
  List<String> keywords = const <String>[],
  DateTime? date,
}) {
  return SearchResult(
    kind: kind,
    id: '${kind.name}:$title',
    title: title,
    subtitle: subtitle,
    keywords: keywords,
    date: date,
  );
}

void main() {
  group('SearchRanking.score', () {
    test('a whole-title match beats a prefix beats a word start', () {
      final exact = SearchRanking.score(
        _result(SearchResultKind.topic, 'db'),
        query: 'db',
      );
      final prefix = SearchRanking.score(
        _result(SearchResultKind.topic, 'dbase'),
        query: 'db',
      );
      final wordStart = SearchRanking.score(
        _result(SearchResultKind.topic, 'prod-db'),
        query: 'db',
      );

      expect(exact, greaterThan(prefix));
      expect(prefix, greaterThan(wordStart));
    });

    test('a word start beats a match buried inside a word', () {
      final wordStart = SearchRanking.score(
        _result(SearchResultKind.topic, 'prod-db'),
        query: 'db',
      );
      final buried = SearchRanking.score(
        _result(SearchResultKind.topic, 'sandbox'),
        query: 'db',
      );

      expect(wordStart, greaterThan(buried));
      expect(buried, greaterThan(0));
    });

    test('matching is case insensitive and ignores surrounding spaces', () {
      expect(
        SearchRanking.score(
          _result(SearchResultKind.topic, 'Prod-DB'),
          query: '  prod-db  ',
        ),
        SearchRanking.exactTitle,
      );
    });

    test('a hidden keyword matches, and counts only once', () {
      final score = SearchRanking.score(
        _result(
          SearchResultKind.settings,
          'Theme',
          keywords: <String>['dark', 'dark mode', 'appearance'],
        ),
        query: 'dark',
      );

      expect(score, SearchRanking.keywordMatch);
    });

    test('every word has to land somewhere', () {
      // "alarm sound" is one word from the title and one from the screen the
      // row lives on, which is how a user would describe it.
      final row = _result(
        SearchResultKind.settings,
        'Default sound',
        subtitle: 'Alarms',
      );

      expect(SearchRanking.score(row, query: 'alarm sound'), greaterThan(0));
      expect(SearchRanking.score(row, query: 'sound alarm'), greaterThan(0));
      // "siren" lands nowhere, so the whole thing drops.
      expect(SearchRanking.score(row, query: 'alarm siren'), 0);
    });

    test('a word may land on a hidden keyword', () {
      final row = _result(
        SearchResultKind.settings,
        'Theme',
        keywords: <String>['dark mode', 'appearance'],
      );

      expect(SearchRanking.score(row, query: 'dark theme'), greaterThan(0));
    });

    test('a longer query does not score higher just for being longer', () {
      final row = _result(
        SearchResultKind.settings,
        'Default sound',
        subtitle: 'Alarms',
      );

      // Adding a word that only lands on the subtitle cannot push the score
      // above the single word that lands on the title.
      expect(
        SearchRanking.score(row, query: 'alarm sound'),
        lessThanOrEqualTo(SearchRanking.score(row, query: 'sound')),
      );
    });

    test('nothing matching scores zero, scope bonus included', () {
      expect(
        SearchRanking.score(
          _result(SearchResultKind.topic, 'prod-db'),
          query: 'zzz',
          scope: SearchScope.topics,
        ),
        0,
      );
    });

    test(
      'the scope the user came from lifts a result that already matched',
      () {
        final plain = SearchRanking.score(
          _result(SearchResultKind.topic, 'prod-db'),
          query: 'prod',
        );
        final scoped = SearchRanking.score(
          _result(SearchResultKind.topic, 'prod-db'),
          query: 'prod',
          scope: SearchScope.topics,
        );

        expect(scoped - plain, SearchRanking.scopeBonus);
      },
    );

    test('a date query matches the day, and only that day', () {
      final day = DateTime(2026, 9, 14);
      final onDay = _result(
        SearchResultKind.history,
        'prod-db',
        date: DateTime(2026, 9, 14),
      );
      final otherDay = _result(
        SearchResultKind.history,
        'cache-01',
        date: DateTime(2026, 9, 13),
      );

      expect(
        SearchRanking.score(onDay, query: 'sep 14', queryDate: day),
        greaterThanOrEqualTo(SearchRanking.dateMatch),
      );
      expect(SearchRanking.score(otherDay, query: 'sep 14', queryDate: day), 0);
    });
  });

  group('SearchRanking.rank', () {
    final catalogue = <SearchResult>[
      _result(SearchResultKind.topic, 'prod-db'),
      _result(SearchResultKind.history, 'prod-db', subtitle: 'Sep 14, 3:02 AM'),
      _result(SearchResultKind.settings, 'Alarm sound', keywords: ['sound']),
      _result(SearchResultKind.docs, 'Docker Installation'),
    ];

    test('drops everything that does not match', () {
      final ranked = SearchRanking.rank(catalogue, query: 'docker');

      expect(ranked, hasLength(1));
      expect(ranked.single.kind, SearchResultKind.docs);
    });

    test('an empty query matches nothing', () {
      expect(SearchRanking.rank(catalogue, query: '   '), isEmpty);
    });

    test('scope decides the order when two results score the same', () {
      final fromTopics = SearchRanking.rank(
        catalogue,
        query: 'prod-db',
        scope: SearchScope.topics,
      );
      final fromHistory = SearchRanking.rank(
        catalogue,
        query: 'prod-db',
        scope: SearchScope.history,
      );

      expect(fromTopics.first.kind, SearchResultKind.topic);
      expect(fromHistory.first.kind, SearchResultKind.history);
    });

    test('ties keep the order they were built in', () {
      // Both score the same with no scope, so the catalogue order decides:
      // topics before past alarms.
      final ranked = SearchRanking.rank(catalogue, query: 'prod-db');

      expect(
        ranked.map((r) => r.kind),
        <SearchResultKind>[SearchResultKind.topic, SearchResultKind.history],
      );
    });
  });

  group('SearchRanking.section', () {
    test('groups results and keeps the section order of the best hit', () {
      final sections = SearchRanking.section(<SearchResult>[
        _result(SearchResultKind.settings, 'Alarm sound'),
        _result(SearchResultKind.topic, 'prod-db'),
        _result(SearchResultKind.settings, 'Quiet hours'),
      ]);

      expect(sections.keys, <SearchResultKind>[
        SearchResultKind.settings,
        SearchResultKind.topic,
      ]);
      expect(sections[SearchResultKind.settings], hasLength(2));
    });
  });
}
