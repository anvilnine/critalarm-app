import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _yellow = Color(0xFFFFC93C);
const Color _ink = Color(0xFF1A140F);

/// The accents the alarm looks hand the face: the alarm red, ink, green.
const List<Color> _accents = [
  Color(0xFFF5473A),
  Color(0xFF1A140F),
  Color(0xFF4DF58B),
];

void main() {
  test('the yellow token is the light face fill', () {
    expect(AppColors.light.faceFill, _yellow);
    expect(AppColors.light.yellow, _yellow);
  });

  test('some styles do flush and flash the head, so the switch has '
      'something to hold', () {
    var flushes = 0;
    var flashes = 0;
    for (final style in RingingStyle.values) {
      var flush = 0.0;
      var flash = 0.0;
      for (var i = 0; i <= 200; i++) {
        final frame = ringingFrameFor(style, i / 200);
        if (frame.flush > flush) flush = frame.flush;
        if (frame.flash > flash) flash = frame.flash;
      }
      if (flush > 0) flushes++;
      if (flash > 0) flashes++;
    }
    expect(flushes, greaterThan(0));
    expect(flashes, greaterThan(0));
    final rage = ringingFrameFor(RingingStyle.rage, RingingStyle.rage.stillT);
    expect(rage.flush, greaterThan(0.3), reason: 'the capture pins rage');
  });

  for (final style in RingingStyle.values) {
    test('${style.name}: with the fill kept, the head is yellow and the '
        'features are ink at every moment', () {
      for (final accent in _accents) {
        for (var i = 0; i <= 200; i++) {
          final frame = ringingFrameFor(style, i / 200);
          final colors = ringingFaceColors(
            fill: _yellow,
            accent: accent,
            ink: _ink,
            flush: frame.flush,
            flash: frame.flash,
            keepsFill: true,
          );
          expect(colors.head, _yellow, reason: '$i');
          expect(colors.ink, _ink, reason: '$i');
        }
      }
    });
  }

  test('a blend between two styles keeps the fill too', () {
    final frame = RingingFrame.lerp(
      ringingFrameFor(RingingStyle.rage, RingingStyle.rage.stillT),
      ringingFrameFor(RingingStyle.classic, 0.3),
      0.4,
    );
    expect(frame.flush, greaterThan(0));
    final colors = ringingFaceColors(
      fill: _yellow,
      accent: _ink,
      ink: _ink,
      flush: frame.flush,
      flash: frame.flash,
      keepsFill: true,
    );
    expect(colors.head, _yellow);
  });

  test('without the switch the head flushes and flashes as it always '
      'has', () {
    const red = Color(0xFFF5473A);
    final rest = ringingFaceColors(
      fill: _yellow,
      accent: red,
      ink: _ink,
      flush: 0,
      flash: 0,
    );
    expect(rest, (head: _yellow, ink: _ink));
    final flushed = ringingFaceColors(
      fill: _yellow,
      accent: red,
      ink: _ink,
      flush: 0.5,
      flash: 0,
    );
    expect(flushed.head, Color.lerp(_yellow, red, 0.4));
    expect(flushed.ink, _ink);
    final flashed = ringingFaceColors(
      fill: _yellow,
      accent: red,
      ink: _ink,
      flush: 0,
      flash: 1,
    );
    expect(flashed, (head: _ink, ink: _yellow));
  });

  test('the painter repaints when the switch changes, and is off unless '
      'asked', () {
    final frame = ringingFrameFor(RingingStyle.rage, 0.2);
    final plain = RingingFacePainter(
      frame: frame,
      fillColor: _yellow,
      strokeColor: _ink,
      inkColor: _ink,
      accentColor: _ink,
    );
    final kept = RingingFacePainter(
      frame: frame,
      fillColor: _yellow,
      strokeColor: _ink,
      inkColor: _ink,
      accentColor: _ink,
      keepsFill: true,
    );
    expect(plain.keepsFill, isFalse);
    expect(kept.shouldRepaint(plain), isTrue);
    expect(plain.shouldRepaint(plain), isFalse);
  });

  test('a capture can hold the shuffling face on one style, in a debug '
      'build only', () {
    expect(pinnedRingingStyle(), isNull);
    expect(pinnedRingingStyle(name: 'no_such_face'), isNull);
    expect(pinnedRingingStyle(name: 'rage'), RingingStyle.rage);
    expect(pinnedRingingStyle(name: 'rage', isDebug: false), isNull);
  });
}
