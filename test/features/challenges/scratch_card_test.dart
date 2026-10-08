import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/scratch_card.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card on a 375 point screen: 335 by 128 points.
const double _width = 335;
const double _height = 128;

/// A stroke in points on that card, with the real brush.
void _rub(
  ScratchGrid grid,
  double fromX,
  double fromY,
  double toX,
  double toY, {
  double width = _width,
  double height = _height,
}) => grid.rub(
  fromX: fromX / width,
  fromY: fromY / height,
  toX: toX / width,
  toY: toY / height,
  radiusX: ScratchRule.brushRadius / width,
  radiusY: ScratchRule.brushRadius / height,
);

void main() {
  group('scratchCode', () {
    test('every seed gives four digits that do not start with zero', () {
      final firsts = <String>{};
      for (var seed = 0; seed < 5000; seed++) {
        final code = scratchCode(seed);
        expect(code, matches(RegExp(r'^[1-9][0-9]{3}$')), reason: 'seed $seed');
        expect(code.length, scratchCodeLength);
        firsts.add(code[0]);
      }
      expect(firsts.length, 9);
    });

    test('the same seed gives the same code, and seeds differ', () {
      for (var seed = 0; seed < 200; seed++) {
        expect(scratchCode(seed), scratchCode(seed));
      }
      final codes = {for (var seed = 0; seed < 200; seed++) scratchCode(seed)};
      expect(codes.length, greaterThan(150));
    });

    test('a seed the size of a clock reading works', () {
      final code = scratchCode(DateTime(2026, 10, 8).microsecondsSinceEpoch);
      expect(code, matches(RegExp(r'^[1-9][0-9]{3}$')));
    });

    test('the sample is a code, and is spelled digit by digit', () {
      expect(scratchCodeSample, matches(RegExp(r'^[1-9][0-9]{3}$')));
      expect(scratchCodeSpelled('4827'), '4 8 2 7');
    });
  });

  group('scratchCodeMatches', () {
    bool ok(String typed, [String code = '4827']) =>
        scratchCodeMatches(typed: typed, code: code);

    test('the code matches, with or without spaces around it', () {
      expect(ok('4827'), isTrue);
      expect(ok(' 4827 '), isTrue);
    });

    test('a code with a zero in it is matched digit for digit', () {
      expect(ok('1007', '1007'), isTrue);
      expect(ok('107', '1007'), isFalse);
      expect(ok('01007', '1007'), isFalse);
    });

    test('anything else does not match', () {
      expect(ok(''), isFalse);
      expect(ok('   '), isFalse);
      expect(ok('482'), isFalse);
      expect(ok('48270'), isFalse);
      expect(ok('4 827'), isFalse);
      expect(ok('7284'), isFalse);
      expect(ok('٤٨٢٧'), isFalse);
    });

    test('an empty or broken code is never matched', () {
      expect(ok('', ''), isFalse);
      expect(ok('abcd', 'abcd'), isFalse);
    });
  });

  group('scratchCodeJudge', () {
    ScratchCodeVerdict judge(String typed, {bool isFinal = false}) =>
        scratchCodeJudge(typed: typed, code: '4827', isFinal: isFinal);

    test('typing digit by digit waits, then passes at the fourth', () {
      expect(
        [
          for (final typed in ['4', '48', '482', '4827']) judge(typed),
        ],
        [
          ScratchCodeVerdict.waiting,
          ScratchCodeVerdict.waiting,
          ScratchCodeVerdict.waiting,
          ScratchCodeVerdict.right,
        ],
      );
    });

    test('a wrong code is cleared only at four digits', () {
      expect(judge('9'), ScratchCodeVerdict.waiting);
      expect(judge('999'), ScratchCodeVerdict.waiting);
      expect(judge('4828'), ScratchCodeVerdict.wrong);
    });

    test('done judges a short code, and an empty field waits', () {
      expect(judge('48', isFinal: true), ScratchCodeVerdict.wrong);
      expect(judge('', isFinal: true), ScratchCodeVerdict.waiting);
      expect(judge('  ', isFinal: true), ScratchCodeVerdict.waiting);
    });
  });

  group('ScratchGrid', () {
    test('the code area is 10 by 4 cells in the middle of 16 by 8', () {
      expect(ScratchGrid.codeCells, 40);
      expect(ScratchGrid.isCodeCell(3, 2), isTrue);
      expect(ScratchGrid.isCodeCell(12, 5), isTrue);
      expect(ScratchGrid.isCodeCell(2, 2), isFalse);
      expect(ScratchGrid.isCodeCell(13, 5), isFalse);
      expect(ScratchGrid.isCodeCell(3, 1), isFalse);
      expect(ScratchGrid.isCodeCell(12, 6), isFalse);
    });

    test('a new card has nothing cleared', () {
      final grid = ScratchGrid();
      expect(grid.codeShareCleared, 0);
      expect(grid.isRevealed, isFalse);
    });

    test('one tap clears a little and reveals nothing', () {
      final grid = ScratchGrid();
      _rub(grid, 167, 64, 167, 64);
      expect(grid.codeShareCleared, greaterThan(0));
      expect(grid.codeShareCleared, lessThan(0.2));
      expect(grid.isRevealed, isFalse);
    });

    test('one swipe through the middle is half, and not enough', () {
      final grid = ScratchGrid();
      _rub(grid, 0, 64, 335, 64);
      expect(grid.codeShareCleared, 0.5);
      expect(grid.isRevealed, isFalse);
    });

    test('two swipes over the digits reveal the card', () {
      final grid = ScratchGrid();
      _rub(grid, 40, 48, 300, 48);
      expect(grid.isRevealed, isFalse);
      _rub(grid, 300, 80, 40, 80);
      expect(grid.codeShareCleared, 1);
      expect(grid.isRevealed, isTrue);
    });

    test('rubbing only outside the code never reveals it', () {
      final grid = ScratchGrid();
      // The top edge, the bottom edge and both ends.
      _rub(grid, 0, 0, 335, 0);
      _rub(grid, 0, 128, 335, 128);
      _rub(grid, 10, 0, 10, 128);
      _rub(grid, 325, 0, 325, 128);
      expect(grid.codeShareCleared, 0);
      expect(grid.isRevealed, isFalse);
    });

    test('a fast finger that reports two far points clears the line', () {
      final grid = ScratchGrid();
      _rub(grid, 0, 64, 335, 64);
      for (var column = 0; column < ScratchRule.columns; column++) {
        expect(grid.isCleared(column, 3), isTrue, reason: 'column $column');
        expect(grid.isCleared(column, 4), isTrue, reason: 'column $column');
      }
    });

    test('small scribbles add up to a reveal, and stay revealed', () {
      final grid = ScratchGrid();
      var strokes = 0;
      for (var x = 70.0; x <= 270 && !grid.isRevealed; x += 20) {
        _rub(grid, x, 30, x + 10, 100);
        strokes++;
      }
      expect(grid.isRevealed, isTrue);
      expect(strokes, greaterThan(3));
      _rub(grid, 0, 0, 5, 5);
      expect(grid.isRevealed, isTrue);
    });

    test('the threshold is 60 percent of the code cells', () {
      expect(ScratchRule.revealAt, 0.6);
      final grid = ScratchGrid();
      // A brush small enough to clear one cell at a time.
      void cell(int column, int row) => grid.rub(
        fromX: (column + 0.5) / ScratchRule.columns,
        fromY: (row + 0.5) / ScratchRule.rows,
        toX: (column + 0.5) / ScratchRule.columns,
        toY: (row + 0.5) / ScratchRule.rows,
        radiusX: 0.01,
        radiusY: 0.01,
      );
      var cleared = 0;
      for (var row = 2; row <= 5; row++) {
        for (var column = 3; column <= 12; column++) {
          if (cleared == 24) break;
          expect(grid.isRevealed, isFalse, reason: '$cleared of 40');
          cell(column, row);
          cleared++;
        }
      }
      expect(grid.codeShareCleared, 0.6);
      expect(grid.isRevealed, isTrue);
    });

    test('the same rule holds on a wide card', () {
      final grid = ScratchGrid();
      _rub(grid, 0, 64, 600, 64, width: 600);
      expect(grid.isRevealed, isFalse);
      _rub(grid, 0, 48, 600, 48, width: 600);
      _rub(grid, 0, 80, 600, 80, width: 600);
      expect(grid.isRevealed, isTrue);
    });

    test('points off the card, no brush and broken numbers are harmless', () {
      final grid = ScratchGrid();
      _rub(grid, -500, -500, -400, -400);
      _rub(grid, 5000, 64, 6000, 64);
      grid
        ..rub(
          fromX: 0.5,
          fromY: 0.5,
          toX: 0.5,
          toY: 0.5,
          radiusX: 0,
          radiusY: 0,
        )
        ..rub(
          fromX: double.nan,
          fromY: 0.5,
          toX: 0.5,
          toY: 0.5,
          radiusX: 0.1,
          radiusY: 0.1,
        )
        ..rub(
          fromX: 0.5,
          fromY: 0.5,
          toX: double.infinity,
          toY: 0.5,
          radiusX: 0.1,
          radiusY: 0.1,
        );
      expect(grid.codeShareCleared, 0);
      // A stroke that starts far off the card and crosses it still counts
      // where it crosses, and does not hang.
      _rub(grid, -100000, 64, 100000, 64);
      expect(grid.isRevealed, isFalse);
    });
  });

  group('ScratchRub', () {
    Duration ms(int value) => Duration(milliseconds: value);

    test('the button is offered after five seconds of rubbing', () {
      expect(ScratchRule.revealButtonAfter, const Duration(seconds: 5));
      final rub = ScratchRub()..down(ms(1000));
      expect(rub.isButtonOffered(ms(1000)), isFalse);
      expect(rub.untilButton(ms(1000)), ms(5000));
      expect(rub.isButtonOffered(ms(5999)), isFalse);
      expect(rub.isButtonOffered(ms(6000)), isTrue);
      expect(rub.untilButton(ms(9000)), Duration.zero);
    });

    test('time with no finger on the card does not count', () {
      final rub = ScratchRub();
      expect(rub.isButtonOffered(ms(60000)), isFalse);
      rub
        ..down(ms(0))
        ..up(ms(2000));
      expect(rub.rubbed(ms(50000)), ms(2000));
      rub.down(ms(50000));
      expect(rub.untilButton(ms(50000)), ms(3000));
      expect(rub.isButtonOffered(ms(52999)), isFalse);
      expect(rub.isButtonOffered(ms(53000)), isTrue);
      rub.up(ms(53000));
      expect(rub.isButtonOffered(ms(53000)), isTrue);
    });

    test('a second finger, a stray lift and a clock gone back do nothing', () {
      final rub = ScratchRub()
        ..up(ms(100))
        ..down(ms(1000))
        ..down(ms(3000));
      expect(rub.rubbed(ms(4000)), ms(3000));
      expect(rub.rubbed(ms(500)), Duration.zero);
      rub.up(ms(500));
      expect(rub.rubbed(ms(9000)), Duration.zero);
    });
  });

  group('the scratch card in the registry', () {
    test('runs for any alarm, with a title or without', () {
      final challenge = challengeOf(ChallengeKind.scratchCard)!;
      expect(
        challenge.canRunFor(const ChallengeIncident(topic: 'prod-db')),
        isTrue,
      );
      expect(
        challenge.canRunFor(
          const ChallengeIncident(topic: 'prod-db', alertTitle: 'Down'),
        ),
        isTrue,
      );
    });

    test('its id is the one saved on phones, and it is listed last', () {
      expect(ChallengeKind.scratchCard.id, 'scratch_card');
      expect(challenges.last.kind, ChallengeKind.scratchCard);
    });
  });
}
