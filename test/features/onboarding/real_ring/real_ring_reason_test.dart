import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/presentation/model/real_ring_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_translations.dart';

void main() {
  setUpAll(loadTestTranslations);

  test('every failure has a short title with no full stop', () {
    for (final failure in RealRingFailure.values) {
      final reason = realRingFailureLine(failure);
      expect(reason.title, isNotEmpty, reason: '$failure');
      expect(reason.title.endsWith('.'), isFalse, reason: '$failure');
      // A title is a few words, never the paragraph it used to be.
      expect(reason.title.split(' ').length, lessThanOrEqualTo(7));
    }
  });

  test('a line under a title is a sentence of its own', () {
    for (final reason in [
      for (final failure in RealRingFailure.values)
        realRingFailureLine(failure),
      realRingNoServerReason(),
      realRingNoTopicReason(),
    ]) {
      final line = reason.line;
      if (line == null) continue;
      expect(line.endsWith('.'), isTrue);
      expect(line, isNot(reason.title));
    }
  });

  test('no setup problem says "your server": a Cloud user has none', () {
    for (final reason in [
      for (final failure in RealRingFailure.values)
        realRingFailureLine(failure),
      realRingNoServerReason(),
      realRingNoTopicReason(),
    ]) {
      expect(
        '${reason.title} ${reason.line}'.toLowerCase(),
        isNot(contains('your server')),
      );
    }
  });
}
