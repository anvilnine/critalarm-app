import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('light colors match design system tokens', () {
      const colors = AppColors.light;
      expect(colors.canvas, const Color(0xFFFFC93C));
      expect(colors.canvasAlt, const Color(0xFFFFD866));
      expect(colors.yellow, const Color(0xFFFFC93C));
      expect(colors.surface, const Color(0xFFFFFFFF));
      expect(colors.cream, const Color(0xFFF7F2E9));
      expect(colors.panel, const Color(0xFF1A140F));
      expect(colors.onPanel, const Color(0xFFF7F1EA));
      expect(colors.ink, const Color(0xFF1A140F));
      expect(colors.crit, const Color(0xFFF5473A));
      expect(colors.high, const Color(0xFFFF8A1F));
    });

    test('dark colors match design system tokens', () {
      const colors = AppColors.dark;
      expect(colors.canvas, const Color(0xFF171310));
      expect(colors.canvasAlt, const Color(0xFF201A15));
      expect(colors.yellow, const Color(0xFFFFC93C));
      expect(colors.surface, const Color(0xFF241D18));
      expect(colors.panel, const Color(0xFF0E0B09));
      expect(colors.onPanel, const Color(0xFFF7F1EA));
      expect(colors.ink, const Color(0xFFF7F1EA));
      expect(colors.crit, const Color(0xFFF5473A));
      expect(colors.high, const Color(0xFFFF8A1F));
    });

    test('withSeverity applies correct retinting', () {
      const base = AppColors.light;

      final none = base.withSeverity(SeverityMode.none);
      expect(none.canvas, base.canvas);

      final crit = base.withSeverity(SeverityMode.crit);
      expect(crit.canvas, base.critCanvas);
      expect(crit.canvasAlt, base.critCanvasAlt);
      expect(crit.faceStroke, base.critStroke);
      expect(crit.focusGap, base.critCanvas);

      final high = base.withSeverity(SeverityMode.high);
      expect(high.canvas, base.highCanvas);
      expect(high.canvasAlt, base.highCanvasAlt);
      expect(high.faceStroke, base.highStroke);

      final ack = base.withSeverity(SeverityMode.ack);
      expect(ack.canvas, base.ackCanvas);
      expect(ack.canvasAlt, base.ackCanvasAlt);
      expect(ack.canvasGhost, base.ackGhost);
      expect(ack.canvasGhostStrong, base.ackGhostStrong);
      expect(ack.onCanvas, base.ackText);
      expect(ack.ink, base.ink);
      expect(ack.faceInk, base.ackText);
    });

    test('copyWith creates modified instance', () {
      const base = AppColors.light;
      final modified = base.copyWith(canvas: const Color(0xFF000000));
      expect(modified.canvas, const Color(0xFF000000));
      expect(modified.yellow, base.yellow);
    });

    test('lerp interpolates between two palettes', () {
      const light = AppColors.light;
      const dark = AppColors.dark;

      final mid = light.lerp(dark, 0.5);
      expect(mid.canvas, Color.lerp(light.canvas, dark.canvas, 0.5));
      expect(mid.surface, Color.lerp(light.surface, dark.surface, 0.5));

      expect(light.lerp(null, 0.5), light);
    });
  });

  group('ColorContrast', () {
    test('luminance calculates accurately for black and white', () {
      expect(ColorContrast.relativeLuminance(const Color(0xFF000000)), 0);
      expect(ColorContrast.relativeLuminance(const Color(0xFFFFFFFF)), 1);
    });

    test('contrast ratio computes correctly', () {
      final ratio = ColorContrast.contrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, closeTo(21, 0.01));

      final same = ColorContrast.contrastRatio(
        const Color(0xFF12100C),
        const Color(0xFF12100C),
      );
      expect(same, 1);
    });

    test('wcagGrade assigns correct ratings', () {
      expect(ColorContrast.wcagGrade(7.1), 'AAA');
      expect(ColorContrast.wcagGrade(5), 'AA');
      expect(ColorContrast.wcagGrade(3.5), 'AA large');
      expect(ColorContrast.wcagGrade(2), 'fail');
    });

    test('light theme ink on canvas satisfies AAA', () {
      const colors = AppColors.light;
      final ratio = ColorContrast.contrastRatio(colors.ink, colors.canvas);
      expect(ratio, greaterThan(11));
      expect(ColorContrast.wcagGrade(ratio), 'AAA');
    });

    test('dark theme ink on canvas satisfies AAA', () {
      const colors = AppColors.dark;
      final ratio = ColorContrast.contrastRatio(colors.ink, colors.canvas);
      expect(ratio, greaterThan(11));
      expect(ColorContrast.wcagGrade(ratio), 'AAA');
    });
  });

  group('Radii', () {
    test('token values match design system', () {
      expect(Radii.sm, 10);
      expect(Radii.md, 18);
      expect(Radii.lg, 24);
      expect(Radii.xl, 32);
      expect(Radii.full, 9999);
    });

    test('all helpers return correct BorderRadius', () {
      expect(Radii.smAll, BorderRadius.circular(10));
      expect(Radii.mdAll, BorderRadius.circular(18));
      expect(Radii.lgAll, BorderRadius.circular(24));
      expect(Radii.xlAll, BorderRadius.circular(32));
      expect(Radii.fullAll, BorderRadius.circular(9999));
    });
  });

  group('Spacing', () {
    test('token steps match design system', () {
      expect(Spacing.s1, 4);
      expect(Spacing.s2, 8);
      expect(Spacing.s3, 12);
      expect(Spacing.s4, 16);
      expect(Spacing.s5, 24);
      expect(Spacing.s6, 32);
      expect(Spacing.s7, 48);
      expect(Spacing.s8, 64);
      expect(Spacing.s9, 96);
    });

    test('named aliases match step values', () {
      expect(Spacing.xs, Spacing.s1);
      expect(Spacing.sm, Spacing.s2);
      expect(Spacing.md, Spacing.s4);
      expect(Spacing.lg, Spacing.s5);
      expect(Spacing.xl, Spacing.s6);
      expect(Spacing.xxl, Spacing.s7);
    });
  });

  group('AppDurations', () {
    test('duration tokens match design system', () {
      expect(AppDurations.quick, const Duration(milliseconds: 150));
      expect(AppDurations.base, const Duration(milliseconds: 300));
      expect(AppDurations.slow, const Duration(milliseconds: 400));
      expect(AppDurations.ring, const Duration(milliseconds: 900));
      expect(AppDurations.shake, const Duration(milliseconds: 500));
      expect(AppDurations.look, const Duration(milliseconds: 4000));
    });
  });

  group('AppCurves', () {
    test('curves match design system cubic bezier', () {
      expect(AppCurves.easeOut, const Cubic(0.16, 1, 0.3, 1));
      expect(AppCurves.easeSpring, const Cubic(0.34, 1.2, 0.64, 1));
    });
  });

  group('AppTypography', () {
    test('display style properties', () {
      final style = AppTypography.display(const Color(0xFF12100C));
      expect(style.fontSize, 56);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, const Color(0xFF12100C));
    });

    test('body style properties', () {
      final style = AppTypography.body(const Color(0xFF12100C));
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w400);
    });

    test('label caps properties', () {
      final style = AppTypography.label(const Color(0xFF12100C));
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 1);
    });

    test('mono style properties', () {
      final style = AppTypography.mono(const Color(0xFF12100C));
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w500);
    });
  });

  group('FaceState', () {
    test('contains all canonical and new expression states', () {
      expect(
        FaceState.values,
        containsAll([
          FaceState.calm,
          FaceState.watching,
          FaceState.worried,
          FaceState.alarmed,
          FaceState.acked,
          FaceState.working,
          FaceState.success,
          FaceState.shocked,
          FaceState.laughing,
          FaceState.surprised,
          FaceState.skeptical,
          FaceState.dizzy,
          FaceState.determined,
          FaceState.confused,
          FaceState.sad,
        ]),
      );
      expect(FaceState.values.length, 36);
    });
  });
}
