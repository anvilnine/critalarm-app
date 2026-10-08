import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const kinds = AppInboxRowKind.values;

  group('inboxRowTint', () {
    test('plain, unread and muted rows have no tint', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        expect(inboxRowTint(AppInboxRowKind.normal, colors), isNull);
        expect(inboxRowTint(AppInboxRowKind.unread, colors), isNull);
        expect(inboxRowTint(AppInboxRowKind.muted, colors), isNull);
      }
    });

    test('ringing is red 18 percent, warning orange 18, missed red 12', () {
      const colors = AppColors.light;
      expect(
        inboxRowTint(AppInboxRowKind.ringing, colors),
        colors.crit.withValues(alpha: 0.18),
      );
      expect(
        inboxRowTint(AppInboxRowKind.warning, colors),
        colors.high.withValues(alpha: 0.18),
      );
      expect(
        inboxRowTint(AppInboxRowKind.missed, colors),
        colors.crit.withValues(alpha: 0.12),
      );
    });

    test('acknowledged is the cobalt tint and handled is cream', () {
      const colors = AppColors.light;
      expect(
        inboxRowTint(AppInboxRowKind.acknowledged, colors),
        const Color(0xFFDCE0FF),
      );
      expect(inboxRowTint(AppInboxRowKind.handled, colors), colors.cream);
      expect(colors.cream, const Color(0xFFF7F2E9));
    });

    test('every tinted kind has a tint of its own', () {
      final tints = [
        for (final k in kinds) ?inboxRowTint(k, AppColors.light),
      ];
      expect(tints.toSet().length, tints.length);
    });
  });

  group('inboxRowFace', () {
    test('only a topic that needs a look wears a face', () {
      expect(inboxRowFace(AppInboxRowKind.ringing), FaceState.alarmed);
      expect(inboxRowFace(AppInboxRowKind.acknowledged), FaceState.acked);
      expect(inboxRowFace(AppInboxRowKind.warning), FaceState.worried);
      expect(inboxRowFace(AppInboxRowKind.handled), FaceState.happy);
      expect(inboxRowFace(AppInboxRowKind.normal), isNull);
      expect(inboxRowFace(AppInboxRowKind.unread), isNull);
      expect(inboxRowFace(AppInboxRowKind.muted), isNull);
    });

    test('a missed alarm has a tint and no face', () {
      expect(inboxRowFace(AppInboxRowKind.missed), isNull);
      expect(inboxRowTint(AppInboxRowKind.missed, AppColors.light), isNotNull);
    });
  });

  group('inboxRowNeedsYou', () {
    test('ringing, acknowledged, warning, missed and handled need you', () {
      final needs = kinds.where(inboxRowNeedsYou).toSet();
      expect(needs, {
        AppInboxRowKind.ringing,
        AppInboxRowKind.acknowledged,
        AppInboxRowKind.warning,
        AppInboxRowKind.missed,
        AppInboxRowKind.handled,
      });
    });
  });

  group('inboxRowTimeColor', () {
    // The sheet is the surface colour, and a tint lies on top of it.
    for (final (name, colors) in [
      ('light', AppColors.light),
      ('dark', AppColors.dark),
    ]) {
      test('the time reads on its own tint in the $name theme', () {
        for (final kind in kinds) {
          final tint = inboxRowTint(kind, colors);
          final ground = tint == null
              ? colors.surface
              : Color.alphaBlend(tint, colors.surface);
          expect(
            _contrast(inboxRowTimeColor(kind, colors), ground),
            greaterThanOrEqualTo(4.5),
            reason: '$kind',
          );
        }
      });
    }
  });

  group('inboxUnreadText', () {
    test('caps at 99+', () {
      expect(inboxUnreadText(1), '1');
      expect(inboxUnreadText(99), '99');
      expect(inboxUnreadText(100), '99+');
      expect(inboxUnreadText(1234), '99+');
    });
  });
}
