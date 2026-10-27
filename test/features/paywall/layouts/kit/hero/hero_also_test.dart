import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('heroShowsAlsoIncluded', () {
    test('only with a lead and at least one other benefit', () {
      expect(heroShowsAlsoIncluded(hasLead: true, benefitCount: 4), isTrue);
      expect(heroShowsAlsoIncluded(hasLead: true, benefitCount: 2), isTrue);
      expect(heroShowsAlsoIncluded(hasLead: true, benefitCount: 1), isFalse);
      expect(heroShowsAlsoIncluded(hasLead: false, benefitCount: 4), isFalse);
      expect(heroShowsAlsoIncluded(hasLead: true, benefitCount: 0), isFalse);
    });
  });

  group('heroRowCentres', () {
    test('with no label the rows sit one gap apart', () {
      expect(
        heroRowCentres(rowHeights: [20, 16, 16], rowGap: 5, top: 0),
        [10, 33, 54],
      );
    });

    test('the label block replaces the gap between the first two rows', () {
      expect(
        heroRowCentres(
          rowHeights: [20, 16, 16],
          rowGap: 5,
          top: 0,
          alsoBlock: 30,
        ),
        [10, 58, 79],
      );
    });

    test('top moves every centre', () {
      expect(
        heroRowCentres(rowHeights: [20], rowGap: 5, top: 40),
        [50],
      );
    });

    test('a single row has no label to make room for', () {
      expect(
        heroRowCentres(rowHeights: [20], rowGap: 5, top: 0, alsoBlock: 30),
        [10],
      );
    });
  });
}
