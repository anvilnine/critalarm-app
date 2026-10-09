import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge_chip_picture.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_chip.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_translations.dart';

void main() {
  setUpAll(loadTestTranslations);

  Widget wrap(Widget child, {double textScale = 1, double width = 390}) =>
      MaterialApp(
        theme: buildLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );

  RenderParagraph labelOf(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text));

  Container shellOf(WidgetTester tester) => tester.widget<Container>(
    find
        .descendant(
          of: find.byType(PersonalizeChip),
          matching: find.byType(Container),
        )
        .first,
  );

  // Wide enough to reach the chip's widest: about 185 points at 13 point
  // type, against 140 of room for words.
  const long = 'Type the topic name now';

  testWidgets('picking a chip does not cut its label', (tester) async {
    await tester.pumpWidget(wrap(PersonalizeChip(label: long, onTap: () {})));
    final plainWidth = tester.getSize(find.byType(PersonalizeChip)).width;
    final plainWords = labelOf(tester, long).size.width;

    await tester.pumpWidget(
      wrap(PersonalizeChip(label: long, isSelected: true, onTap: () {})),
    );
    final pickedWidth = tester.getSize(find.byType(PersonalizeChip)).width;

    // The tick is added to the chip, never taken from the words.
    expect(pickedWidth, greaterThan(plainWidth));
    expect(labelOf(tester, long).size.width, moreOrLessEquals(plainWords));
  });

  testWidgets('a tried chip and a picked chip carry different marks', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(PersonalizeChip(label: 'Yours', isMarked: true, onTap: () {})),
    );
    final tried = shellOf(tester);
    expect(tried.foregroundDecoration, isA<DashedOutline>());
    expect((tried.decoration! as BoxDecoration).border!.top.width, 1);
    expect(find.byType(AppGlyph), findsNothing);

    await tester.pumpWidget(
      wrap(PersonalizeChip(label: 'Siren', isSelected: true, onTap: () {})),
    );
    final picked = shellOf(tester);
    expect(picked.foregroundDecoration, isNull);
    expect((picked.decoration! as BoxDecoration).border!.top.width, 2);
    expect(find.byType(AppGlyph), findsOneWidget);
  });

  testWidgets('the lock badge stays clear of a label on two lines', (
    tester,
  ) async {
    const label = 'Pulsing klaxon long';
    await tester.pumpWidget(
      wrap(
        FeatureLock(
          decision: const FeatureLocked(Holding.pro),
          planWord: 'Pro',
          lockedWord: 'locked',
          badgeSeat: FeatureLockSeat.above,
          badgeOverhang: PersonalizeStrip.badgeOverhang,
          child: PersonalizeChip(label: label, onTap: () {}),
        ),
        textScale: 1.3,
      ),
    );
    final words = tester.getRect(find.text(label));
    final badge = tester.getRect(find.byType(ProBadge));

    // Two lines, the case the badge used to cover.
    expect(words.height, greaterThan(30));
    expect(badge.overlaps(words), isFalse);
  });

  testWidgets('a challenge chip is a picture and one word, and speaks its '
      'full name', (tester) async {
    for (final kind in ChallengeKind.values) {
      final word = challengeChipWordKey(kind).tr();
      expect(word.trim().split(' '), hasLength(1), reason: kind.id);

      await tester.pumpWidget(
        wrap(
          PersonalizeChip(
            label: word,
            spokenLabel: 'Full name of ${kind.id}',
            picture: (color) => ChallengeChipPicture(kind: kind, color: color),
            onTap: () {},
          ),
        ),
      );
      expect(find.text(word), findsOneWidget);
      expect(find.byType(ChallengeChipPicture), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(PersonalizeChip)).label,
        'Full name of ${kind.id}',
      );
      // One line, not cut, on a phone at the default size.
      expect(labelOf(tester, word).didExceedMaxLines, isFalse);
    }
  });

  group('the strip', () {
    test('fades only an edge with more past it', () {
      expect(stripFadesFor(before: 0, after: 0), (start: false, end: false));
      expect(stripFadesFor(before: 0, after: 40), (start: false, end: true));
      expect(stripFadesFor(before: 12, after: 40), (start: true, end: true));
      expect(stripFadesFor(before: 12, after: 0), (start: true, end: false));
    });

    testWidgets('fades its end when chips run past it, and not otherwise', (
      tester,
    ) async {
      List<Widget> chips(int count) => [
        for (var i = 0; i < count; i++)
          PersonalizeChip(label: 'Sound number $i', onTap: () {}),
      ];
      await tester.pumpWidget(wrap(PersonalizeStrip(children: chips(8))));
      await tester.pump();
      expect(find.byType(ShaderMask), findsOneWidget);

      await tester.pumpWidget(wrap(PersonalizeStrip(children: chips(1))));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
    });
  });
}
