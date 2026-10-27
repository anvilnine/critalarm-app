import 'package:critalarm/features/topics/domain/home_card/expected_setup.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter_test/flutter_test.dart';

const HeldTopic _off = (name: 'prod-db', isCritical: false);
const HeldTopic _on = (name: 'uptime-kuma', isCritical: true);

void main() {
  group('expectedSetupFor', () {
    test('a phone whose flags say nothing expects nothing', () {
      expect(expectedSetupFor(isOpen: false, topics: null), isNull);
      expect(expectedSetupFor(isOpen: false, topics: [_off]), isNull);
    });

    test('no topic list held: the waiting card, with no topic named', () {
      final expected = expectedSetupFor(isOpen: true, topics: null)!;
      expect(expected.checklist.hasCriticalTopic, isTrue);
      expect(expected.checklist.hasFirstMessage, isFalse);
      expect(expected.firstTopic, isNull);
      expect(expected.watchedTopic, isNull);
    });

    test('a held list with no Critical topic expects the setup card', () {
      final expected = expectedSetupFor(isOpen: true, topics: [_off])!;
      expect(
        expected.checklist,
        const SetupChecklist(
          isVisible: true,
          hasServer: true,
          hasTopics: true,
          hasCriticalTopic: false,
          hasFirstMessage: false,
        ),
      );
      expect(expected.firstTopic, 'prod-db');
      expect(expected.watchedTopic, 'prod-db');
    });

    test('a held list with a Critical topic expects the waiting card', () {
      final expected = expectedSetupFor(isOpen: true, topics: [_off, _on])!;
      expect(expected.checklist.hasCriticalTopic, isTrue);
      expect(expected.firstTopic, 'prod-db');
      // The Critical topic is the one watched, as the checklist picks it.
      expect(expected.watchedTopic, 'uptime-kuma');
    });

    test('a held list with no topic expects nothing: no topics is next', () {
      expect(expectedSetupFor(isOpen: true, topics: const []), isNull);
    });
  });
}
