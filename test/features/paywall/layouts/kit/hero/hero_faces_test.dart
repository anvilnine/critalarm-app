import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_faces.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the sad face has wet eyes and one tear', () {
    final shape = heroFaceShape(HeroFace.sad);
    expect(shape.props.map((p) => p.kind), [PropKind.tear]);
    for (final eye in [shape.leftEye, shape.rightEye]) {
      expect(eye.ball, greaterThan(eye.pupilRadius));
      expect(eye.shineRadius, greaterThan(0));
    }
  });

  test('the sad face keeps the rig brows and frown', () {
    final shape = heroFaceShape(HeroFace.sad);
    // BrowShape and MouthShape have no ==, and the hero face reuses the
    // rig's own objects, so identity is the right check.
    expect(shape.leftBrow, same(sadFace.leftBrow));
    expect(shape.rightBrow, same(sadFace.rightBrow));
    expect(shape.mouth, same(sadFace.mouth));
  });

  test('the calm face is the rig calm face, with no prop', () {
    final shape = heroFaceShape(HeroFace.calm);
    expect(shape, same(faceFor(FaceState.calm)));
    expect(shape.props, isEmpty);
  });

  test('turning from sad to calm fades the tear out', () {
    final half = heroShapeFor(
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
      faceBlend: 0.5,
    );
    final tear = half.props.singleWhere((p) => p.kind == PropKind.tear);
    expect(tear.alpha, lessThan(1));
    expect(tear.alpha, greaterThan(0));
    final done = heroShapeFor(
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
    );
    expect(done.props, isEmpty);
  });

  test('every hero face still has a shape', () {
    for (final face in HeroFace.values) {
      expect(() => heroFaceShape(face), returnsNormally, reason: '$face');
    }
  });
}
