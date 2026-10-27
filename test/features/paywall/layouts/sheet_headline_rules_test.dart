import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_headline_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a long name', () {
    test('3, 12, 16, 17, 40 and 64 characters', () {
      for (final length in [3, 12, 16, 17, 40, 64]) {
        expect(
          sheetTopicHeadlineFor(name: 'a' * length, fits: true),
          length <= 16 ? SheetTopicHeadline.named : SheetTopicHeadline.generic,
          reason: '$length',
        );
      }
    });

    test('is counted in characters, so an emoji is one', () {
      expect(
        sheetTopicHeadlineFor(name: '\u{1F514}' * 16, fits: true),
        SheetTopicHeadline.named,
      );
      expect(
        sheetTopicHeadlineFor(name: '\u{1F514}' * 17, fits: true),
        SheetTopicHeadline.generic,
      );
    });

    test('gives the headline with no name, and never a cut name', () {
      const name = 'nightly-database-backup-eu-west-region-1';
      expect(
        sheetTopicHeadlineFor(name: name, fits: true),
        SheetTopicHeadline.generic,
      );
      expect(sheetHeadlineName(name), isNull);
      expect(sheetHeadlineName('billing-api'), 'billing-api');
      expect(sheetHeadlineName('a' * 16), 'a' * 16);
      expect(sheetHeadlineName(''), isNull);
      expect(sheetHeadlineName(null), isNull);
    });
  });

  group('sheetTopicHeadlineFor', () {
    test('the named headline when there is a name and it fits', () {
      expect(
        sheetTopicHeadlineFor(name: 'billing-api', fits: true),
        SheetTopicHeadline.named,
      );
    });

    test(
      'the plain headline with no name, or when two lines are not enough',
      () {
        expect(
          sheetTopicHeadlineFor(name: null, fits: true),
          SheetTopicHeadline.generic,
        );
        expect(
          sheetTopicHeadlineFor(name: '', fits: true),
          SheetTopicHeadline.generic,
        );
        expect(
          sheetTopicHeadlineFor(name: 'billing-api', fits: false),
          SheetTopicHeadline.generic,
        );
      },
    );
  });

  group('sheetHeadlineRepeats', () {
    const tapped = ['2 of 2 critical topics used', 'No limit on billing-api'];

    test('a headline that says what the card says repeats it', () {
      expect(sheetHeadlineRepeats('No limit on billing-api', tapped), isTrue);
      expect(
        sheetHeadlineRepeats('2 of 2 critical topics used', tapped),
        isTrue,
      );
    });

    test('Make billing-api critical does not', () {
      expect(
        sheetHeadlineRepeats('Make billing-api critical', tapped),
        isFalse,
      );
      expect(
        sheetHeadlineRepeats('Make this topic critical', tapped),
        isFalse,
      );
    });

    test('case and punctuation do not hide a repeat', () {
      expect(sheetHeadlineRepeats('NO LIMIT ON BILLING-API!', tapped), isTrue);
    });

    test('an empty headline repeats nothing', () {
      expect(sheetHeadlineRepeats('', tapped), isFalse);
    });
  });

  group('sheetShowsLeadLine', () {
    test('the check line goes when a tag already says the lead', () {
      expect(
        sheetShowsLeadLine(
          hasTag: true,
          headline: 'Make a critical',
          leadLine: 'Unlimited critical topics',
        ),
        isFalse,
      );
    });

    test('it goes when the headline already says it', () {
      expect(
        sheetShowsLeadLine(
          hasTag: false,
          headline: 'Unlimited critical topics',
          leadLine: 'Unlimited critical topics',
        ),
        isFalse,
      );
    });

    test('it stays when nothing else says the lead', () {
      expect(
        sheetShowsLeadLine(
          hasTag: false,
          headline: 'Alarms on your home screen',
          leadLine: 'Home screen widgets',
        ),
        isTrue,
      );
    });
  });
}
