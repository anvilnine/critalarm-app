import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPrefsRecentSearchesRepository> _repository([
  List<String>? stored,
]) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'search_recent_queries': ?stored,
  });
  return SharedPrefsRecentSearchesRepository(
    await SharedPreferences.getInstance(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsRecentSearchesRepository', () {
    test('starts empty', () async {
      final repository = await _repository();

      expect((await repository.getRecent()).getOrNull(), isEmpty);
    });

    test('puts the newest search first', () async {
      final repository = await _repository();

      await repository.add('prod-db');
      final list = (await repository.add('cache-01')).getOrNull();

      expect(list, <String>['cache-01', 'prod-db']);
    });

    test(
      'searching the same thing again moves it up instead of repeating',
      () async {
        final repository = await _repository(<String>['cache-01', 'prod-db']);

        final list = (await repository.add('prod-db')).getOrNull();

        expect(list, <String>['prod-db', 'cache-01']);
      },
    );

    test(
      'different capitals are the same search, newest spelling wins',
      () async {
        final repository = await _repository(<String>['prod-db']);

        final list = (await repository.add('PROD-DB')).getOrNull();

        expect(list, <String>['PROD-DB']);
      },
    );

    test('drops the oldest once the list is full', () async {
      final repository = await _repository();

      for (var i = 0; i < SharedPrefsRecentSearchesRepository.max + 3; i++) {
        await repository.add('query-$i');
      }
      final list = (await repository.getRecent()).getOrNull();

      expect(list, hasLength(SharedPrefsRecentSearchesRepository.max));
      expect(list!.first, 'query-10');
      expect(list.contains('query-0'), isFalse);
    });

    test('an empty search is not remembered', () async {
      final repository = await _repository(<String>['prod-db']);

      final list = (await repository.add('   ')).getOrNull();

      expect(list, <String>['prod-db']);
    });

    test('the search is stored trimmed', () async {
      final repository = await _repository();

      final list = (await repository.add('  prod-db  ')).getOrNull();

      expect(list, <String>['prod-db']);
    });

    test('clear empties the list', () async {
      final repository = await _repository(<String>['prod-db', 'cache-01']);

      await repository.clear();

      expect((await repository.getRecent()).getOrNull(), isEmpty);
    });
  });
}
