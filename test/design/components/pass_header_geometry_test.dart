import 'package:critalarm/design/components/pass_header_geometry.dart';
import 'package:critalarm/design/components/pass_page.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 390;
const double _safeTop = 47;

PassHeaderPose _at(
  double offset, {
  double width = _width,
  double scale = 1,
  double trailing = 0,
  double? restValueHeight,
}) => passHeaderPoseAt(
  offset: offset,
  width: width,
  textScale: scale,
  trailingWidth: trailing,
  safeTop: _safeTop,
  restValueHeight: restValueHeight,
);

void main() {
  group('at rest', () {
    test('the label is at the header spot and the value is under it', () {
      final pose = _at(0);
      expect(pose.progress, 0);
      expect(pose.labelLeft, kPassSidePadding);
      expect(pose.labelTop, _safeTop + kPassHeaderTop);
      expect(pose.valueLeft, kPassSidePadding);
      expect(pose.valueTop, _safeTop + kPassHeaderTop + 11 * 1.2 + 4);
      expect(pose.valueSize, kPassPageValueSize);
      expect(pose.valueScale, 1);
      expect(pose.valueMaxLines, isNull);
      expect(pose.valueWidth, _width - 2 * kPassSidePadding);
    });

    test('a negative offset (a bounce) is the resting header', () {
      expect(_at(-30).progress, 0);
    });
  });

  group('collapsed', () {
    test('the block sits beside the ring, on its centre line', () {
      final pose = _at(10000);
      expect(pose.progress, 1);
      expect(pose.isCollapsed, isTrue);
      expect(pose.labelLeft, kPassRingLeft + kPassRingSize + 12);
      expect(pose.valueLeft, pose.labelLeft);
      expect(pose.valueSize, kPassCollapsedValueSize);
      expect(pose.valueMaxLines, 1);
      final top = pose.labelTop;
      final bottom = pose.valueTop + pose.valueSize * pose.valueScale * 1.05;
      final centre = (top + bottom) / 2;
      expect(
        centre,
        closeTo(_safeTop + kPassRingTop + kPassRingSize / 2, 0.01),
      );
    });

    test('keeps clear of a trailing control', () {
      final free = _at(10000);
      final held = _at(10000, trailing: 100);
      expect(held.labelLeft, free.labelLeft);
      expect(
        held.labelLeft + held.labelWidth,
        _width - kPassRingLeft - 100 - 12,
      );
      expect(held.valueWidth, held.labelWidth);
      expect(held.labelWidth, lessThan(free.labelWidth));
    });

    test('stays pinned past the end of the collapse', () {
      expect(_at(300), _at(5000));
    });

    test('is the same at every text scale in the label and value size', () {
      for (final scale in const [1.0, 1.3, 2.0]) {
        final pose = _at(10000, scale: scale);
        expect(pose.valueSize, kPassCollapsedValueSize);
        expect(pose.valueScale, lessThanOrEqualTo(kPassCollapsedMaxTextScale));
        expect(pose.labelHeight, 11 * 1.2 * scale.clamp(1.0, 1.3));
      }
    });
  });

  group('on the way', () {
    test('the label rises and moves right, and the value steps down', () {
      var before = _at(0);
      for (var offset = 4.0; offset <= before.distance + 4; offset += 4) {
        final pose = _at(offset);
        expect(pose.labelTop, lessThanOrEqualTo(before.labelTop));
        expect(pose.labelLeft, greaterThanOrEqualTo(before.labelLeft));
        expect(pose.valueSize, lessThanOrEqualTo(before.valueSize));
        before = pose;
      }
    });

    test('follows the offset alone, a half way offset is half way', () {
      final end = _at(10000);
      final half = _at(end.distance / 2);
      expect(half.progress, closeTo(0.5, 1e-9));
      expect(
        half.valueSize,
        closeTo((kPassPageValueSize + kPassCollapsedValueSize) / 2, 1e-9),
      );
    });

    test('the label is clear of the ring before it rises past it', () {
      // The ring spans down to its bottom edge. The label's top may pass that
      // line only once it is to the right of the ring.
      const ringBottom = _safeTop + kPassRingTop + kPassRingSize;
      const ringRight = kPassRingLeft + kPassRingSize;
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final width in const [320.0, 390.0]) {
          final end = _at(10000, scale: scale, width: width);
          for (var offset = 0.0; offset <= end.distance; offset += 1) {
            final pose = _at(offset, scale: scale, width: width);
            if (pose.labelTop < ringBottom) {
              expect(
                pose.labelLeft,
                greaterThanOrEqualTo(ringRight),
                reason: 'offset $offset, scale $scale, width $width',
              );
            }
          }
        }
      }
    });

    test('the value stays clear of the body that rises under it', () {
      // The body rises one to one with the scroll, from just under the value
      // at rest. The value's lines must end above it all the way.
      for (final scale in const [1.0, 2.0]) {
        for (final lines in const [1, 2, 3]) {
          final restValue = lines * kPassPageValueSize * scale * 1.05;
          final end = _at(10000, scale: scale, restValueHeight: restValue);
          const restTop = _safeTop + kPassHeaderTop;
          final labelHeight = _at(0, scale: scale).labelHeight;
          final restBottom = restTop + labelHeight + 4 + restValue;
          for (var offset = 0.0; offset <= end.distance; offset += 1) {
            final pose = _at(offset, scale: scale, restValueHeight: restValue);
            final shown = pose.valueMaxLines ?? lines;
            final lineHeight = pose.valueSize * pose.valueScale * 1.05;
            final bodyTop = restBottom - offset;
            expect(
              pose.valueTop + shown * lineHeight,
              lessThanOrEqualTo(bodyTop + 0.5),
              reason: '$lines lines, scale $scale, offset $offset',
            );
          }
        }
      }
    });

    test('keeps the lines it had at rest on the way, one when collapsed', () {
      const restValue = 2 * kPassPageValueSize * 2 * 1.05;
      expect(_at(0, scale: 2, restValueHeight: restValue).valueMaxLines, null);
      expect(_at(30, scale: 2, restValueHeight: restValue).valueMaxLines, 2);
      expect(_at(9999, scale: 2, restValueHeight: restValue).valueMaxLines, 1);
    });
  });

  group('large text and a narrow phone', () {
    test('a taller value takes a longer scroll to collapse', () {
      final one = _at(0, scale: 2).distance;
      final three = _at(0, scale: 2, restValueHeight: 3 * 84 * 1.05).distance;
      expect(three, greaterThan(one));
    });

    test('the collapsed block fits the bar at twice the text size', () {
      final pose = _at(10000, scale: 2, width: 320);
      final bottom = pose.valueTop + pose.valueSize * pose.valueScale * 1.05;
      // The bar is the inset and 56 points.
      expect(pose.labelTop, greaterThanOrEqualTo(_safeTop));
      expect(bottom, lessThanOrEqualTo(_safeTop + 56));
      expect(pose.labelWidth, greaterThan(0));
    });

    test('a very narrow column never has a negative width', () {
      final pose = _at(10000, width: 140, trailing: 100);
      expect(pose.labelWidth, greaterThanOrEqualTo(0));
    });
  });
}
