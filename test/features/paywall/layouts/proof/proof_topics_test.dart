import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_topics.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up topic names.
const _a = ProofTopic('alpha', rings: true); // l10n-ok: demo data
const _b = ProofTopic('bravo', rings: true); // l10n-ok: demo data
const _c = ProofTopic('charlie'); // l10n-ok: demo data

List<String> _names(List<ProofTopic> topics) => [
  for (final topic in topics) topic.name,
];

List<bool> _rings(List<ProofTopic> topics) => [
  for (final topic in topics) topic.rings,
];

void main() {
  group('proofTopicsFor', () {
    test('no topics draws the demo list', () {
      final rows = proofTopicsFor(const []);

      expect(rows, proofDemoTopics);
    });

    test('one topic keeps its name first and pads with demo names', () {
      final rows = proofTopicsFor(const [_a]);

      expect(rows, hasLength(4));
      expect(rows.first.name, 'alpha');
      expect(_names(rows).toSet(), hasLength(4));
      expect(_rings(rows), [true, true, false, false]);
    });

    test('one quiet topic is drawn past the cap, never ringing', () {
      final rows = proofTopicsFor(const [_c]);

      expect(_names(rows).indexOf('charlie'), 2);
      expect(_rings(rows), [true, true, false, false]);
    });

    test('three topics are kept in order and one demo name is added', () {
      final rows = proofTopicsFor(const [_a, _b, _c]);

      expect(_names(rows).take(3), ['alpha', 'bravo', 'charlie']);
      expect(rows, hasLength(4));
      expect(_rings(rows), [true, true, false, false]);
    });

    test('ten topics are trimmed to the rows drawn', () {
      final ten = [
        for (var i = 0; i < 10; i++) ProofTopic('topic-$i', rings: i < 2),
      ];

      final rows = proofTopicsFor(ten);

      expect(_names(rows), ['topic-0', 'topic-1', 'topic-2', 'topic-3']);
      expect(_rings(rows), [true, true, false, false]);
    });

    test('topics that ring come first, wherever they were in the list', () {
      final ten = [
        for (var i = 0; i < 10; i++) ProofTopic('topic-$i', rings: i >= 8),
      ];

      final rows = proofTopicsFor(ten);

      expect(_names(rows), ['topic-8', 'topic-9', 'topic-0', 'topic-1']);
      expect(_rings(rows), [true, true, false, false]);
    });

    test('ringing topics past the cap are the refused rows', () {
      final ten = [
        for (var i = 0; i < 10; i++) ProofTopic('topic-$i', rings: i.isEven),
      ];

      final rows = proofTopicsFor(ten);

      expect(_names(rows), ['topic-0', 'topic-2', 'topic-4', 'topic-6']);
      expect(_rings(rows), [true, true, false, false]);
    });

    test('never fewer than three rows, whatever is asked for', () {
      for (final asked in [-1, 0, 1, 2, 3]) {
        for (final input in [
          const <ProofTopic>[],
          const [_a],
          const [_a, _b, _c],
        ]) {
          expect(proofTopicsFor(input, rows: asked), hasLength(3));
        }
      }
    });

    test('there is always a row that rings and a row that is refused', () {
      for (final cap in [-3, 0, 1, 2, 3, 99]) {
        for (final rows in [3, 4, 6]) {
          final rings = _rings(
            proofTopicsFor(const [_a], rows: rows, cap: cap),
          );

          expect(rings.first, isTrue, reason: 'cap $cap, rows $rows');
          expect(rings.last, isFalse, reason: 'cap $cap, rows $rows');
          // Ringing rows first, with no gap.
          expect(rings.skipWhile((r) => r).contains(true), isFalse);
        }
      }
    });

    test('repeated and blank names are dropped', () {
      final rows = proofTopicsFor(const [
        _a,
        ProofTopic('alpha'), // l10n-ok: demo data
        ProofTopic('  '),
        _c,
      ]);

      expect(_names(rows).where((n) => n == 'alpha'), hasLength(1));
      expect(_names(rows).every((n) => n.trim().isNotEmpty), isTrue);
      expect(rows, hasLength(4));
    });

    test('more rows than there are demo names still fills every row', () {
      final rows = proofTopicsFor(const [], rows: 7);

      expect(rows, hasLength(7));
      expect(_names(rows).toSet(), hasLength(7));
    });
  });
}
