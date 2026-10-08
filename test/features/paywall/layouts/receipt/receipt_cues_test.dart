import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what the print sounds like', () {
    test('one line cue for each line and for the total, in order', () {
      for (final count in [2, 3, 5, 9]) {
        final cues = receiptCues(count);
        final lines = [
          for (final beat in cues)
            if (beat.cue == PaywallCue.line) beat.at,
        ];
        expect(lines, hasLength(count + 1), reason: '$count');
        for (var i = 1; i < lines.length; i++) {
          expect(lines[i], greaterThan(lines[i - 1]), reason: '$count');
        }
        expect(lines.last, ReceiptTimeline.totalAt(count));
        expect(lines.first, greaterThan(ReceiptTimeline.feedStart));
        expect(lines.last, lessThan(ReceiptTimeline.feedEnd));
      }
    });

    test('a line is heard as its ink starts to come up', () {
      const count = 5;
      for (var step = 1; step <= count + 1; step++) {
        final at = ReceiptTimeline.printsAt(step, count);
        expect(ReceiptTimeline.ink(at - 0.01, step, count + 3), 0);
        expect(ReceiptTimeline.ink(at + 0.03, step, count + 3), greaterThan(0));
      }
    });

    test('then the stamp, then the first preview, and no printing sound', () {
      final cues = receiptCues(5);
      final tail = cues.sublist(cues.length - 2);
      expect(tail.first.cue, PaywallCue.stamp);
      expect(tail.first.at, ReceiptTimeline.stampAt);
      expect(tail.last.cue, PaywallCue.rise);
      // The preview is on its way out, and the stamp has sounded.
      expect(tail.last.at, greaterThan(ReceiptTimeline.peekStart));
      expect(tail.last.at, lessThan(ReceiptTimeline.restAt));
      expect(
        tail.last.at - tail.first.at,
        greaterThanOrEqualTo(0.33),
      );
      expect(cues.map((beat) => beat.cue), isNot(contains(PaywallCue.print)));
      for (var i = 1; i < cues.length; i++) {
        expect(cues[i].at, greaterThan(cues[i - 1].at));
      }
    });
  });
}
