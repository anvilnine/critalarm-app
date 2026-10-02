import 'package:critalarm/design/faces/face_ripple.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('happyRippleFaces', () {
    test('holds only celebratory faces', () {
      const banned = {
        FaceState.alarmed,
        FaceState.shocked,
        FaceState.worried,
        FaceState.sad,
        FaceState.dizzy,
        FaceState.determined,
        FaceState.confused,
        FaceState.working,
        FaceState.skeptical,
        FaceState.blink,
      };
      expect(happyRippleFaces.where(banned.contains), isEmpty);
      expect(happyRippleFaces.toSet().length, happyRippleFaces.length);
    });
  });

  group('pickRippleFace', () {
    test('in order by default, as the welcome screen runs it', () {
      for (var wave = -1; wave < 4; wave++) {
        for (var cell = 0; cell < 20; cell++) {
          expect(
            pickRippleFace(
              allRippleFaces,
              wave: wave,
              cell: cell,
              cellCount: 20,
            ),
            allRippleFaces[(wave.clamp(0, 99) * 20 + cell) %
                allRippleFaces.length],
          );
        }
      }
      expect(allRippleFaces, isNot(contains(FaceState.blink)));
    });

    test('random picks stay in the pool and repeat for the same cell', () {
      final seen = <FaceState>{};
      for (var wave = 0; wave < 12; wave++) {
        for (var cell = 0; cell < 25; cell++) {
          final face = pickRippleFace(
            happyRippleFaces,
            wave: wave,
            cell: cell,
            cellCount: 25,
            random: true,
          );
          expect(happyRippleFaces, contains(face));
          expect(
            pickRippleFace(
              happyRippleFaces,
              wave: wave,
              cell: cell,
              cellCount: 25,
              random: true,
            ),
            face,
          );
          seen.add(face);
          if (wave > 0) {
            expect(
              face,
              isNot(
                pickRippleFace(
                  happyRippleFaces,
                  wave: wave - 1,
                  cell: cell,
                  cellCount: 25,
                  random: true,
                ),
              ),
            );
          }
        }
      }
      expect(seen.length, happyRippleFaces.length);
    });
  });

  group('rippleGrid', () {
    test('default is four columns sized by the tighter side', () {
      final g = rippleGrid(312, 600);
      expect(g.cols, 4);
      expect(g.size, closeTo((312 - 36) / 4, 0.001));
      expect(g.rows, 5);
    });

    test('a box with no room yields no rows', () {
      expect(rippleGrid(300, 20).rows, 0);
    });
  });
}
