import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/search_layout.dart';
import 'package:flutter_test/flutter_test.dart';

SearchResult _r(SearchResultKind kind, String id) =>
    SearchResult(kind: kind, id: id, title: id);

void main() {
  group('nearestFirstEntries', () {
    test('is empty with no sections', () {
      expect(nearestFirstEntries(const {}), isEmpty);
    });

    test('puts the best result first and each header after its rows', () {
      final a = _r(SearchResultKind.topic, 'a');
      final b = _r(SearchResultKind.topic, 'b');
      final c = _r(SearchResultKind.settings, 'c');

      final entries = nearestFirstEntries({
        SearchResultKind.topic: [a, b],
        SearchResultKind.settings: [c],
      });

      expect(entries, [
        SearchRowEntry(a),
        SearchRowEntry(b),
        const SearchHeaderEntry(SearchResultKind.topic),
        SearchRowEntry(c),
        const SearchHeaderEntry(SearchResultKind.settings),
      ]);
    });
  });
}
