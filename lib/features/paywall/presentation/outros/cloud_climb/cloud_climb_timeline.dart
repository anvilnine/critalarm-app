import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';

// The Hosted outro as numbers. One climb drives everything: a single
// progress value, eased slow at the start, steady in the middle and slow at
// the end. The sky is one tall picture the screen climbs through, and every
// layer slides by a share of the same rise, so depth comes from parallax
// alone. Nothing here steps: no floor, no modulo on time, no switch. Every
// value is a pure function of the seconds since the purchase was confirmed.

/// The width the sky was drawn for. A wider or narrower phone centres it.
const double _designWidth = 390;

/// A star: where it sits when the climb starts, its radius and the share of
/// the rise it slides by.
typedef CloudClimbStar = ({double x, double y, double radius, double slide});

/// A cloud: where it sits when the climb starts and how wide it is.
typedef CloudClimbCloud = ({double x, double y, double width});

/// The two server dots' glow, each from 0.25 to 1.
typedef CloudClimbGlow = ({double a, double b});

/// The timeline of the Cloud climb outro.
abstract final class CloudClimbTimeline {
  /// The swap: the outro is taken away and his mascot is on the end
  /// state's.
  static const double end = 4.1;

  /// The end state is built under the outro from here, and the outro fades
  /// its last frame out until [end].
  static const double uncover = 3.9;

  /// The climb starts and ends.
  static const double climbFrom = 0.4;
  static const double climbTo = 3.5;

  /// How far the ground falls in the whole climb.
  static const double reach = 1500;

  /// The sine ease: 0 at 0, 1 at 1, slow at both ends.
  static double sine(double x) =>
      (1 - math.cos(math.pi * x.clamp(0.0, 1.0))) / 2;

  static double _lerp(double a, double b, double x) =>
      x >= 1 ? b : a + (b - a) * x;

  static Offset _lerpOffset(Offset a, Offset b, double x) =>
      Offset(_lerp(a.dx, b.dx, x), _lerp(a.dy, b.dy, x));

  /// How far through the climb, 0 to 1.
  static double climb(double t) => phase(t, climbFrom, climbTo);

  /// How far the ground has fallen. Never goes down.
  static double rise(double t) => sine(climb(t)) * reach;

  /// How fast the climb is, 0 at both ends and 1 in the middle.
  static double speed(double t) => math.sin(math.pi * climb(t));

  // ---- the night

  /// Whether any night shows: from the first point the ground has fallen
  /// until the moon covers the screen.
  static bool hasNight(double t) => rise(t) > 0 && moonProgress(t) < 1;

  /// The y of the night's curved lower edge at its sides. The middle dips
  /// [nightDip] below it.
  static double nightEdge(double t) => rise(t) - 30;
  static const double nightDip = 56;

  // ---- the sky

  static double _across(Size size) => (size.width - _designWidth) / 2;

  /// 22 stars, seeded. They do not twinkle.
  static final List<CloudClimbStar> stars = List.unmodifiable([
    for (var i = 0; i < 22; i++)
      (
        x: 20 + _seeded(i + 40) * 350,
        y: -260 + _seeded(i + 41) * 1080,
        radius: 3 + _seeded(i + 42) * 5,
        slide: 0.05 + _seeded(i + 43) * 0.07,
      ),
  ]);

  static double _seeded(int i) {
    final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Far clouds: dim, a third of the rise, drifting right.
  static const List<CloudClimbCloud> far = [
    (x: 70, y: -40, width: 84),
    (x: 330, y: -250, width: 70),
    (x: 150, y: -470, width: 96),
    (x: 350, y: -640, width: 76),
    (x: 60, y: -820, width: 88),
  ];
  static const double farSlide = 0.32;
  static const double farDrift = 5;

  /// Mid clouds: lighter, most of the rise, drifting left.
  static const List<CloudClimbCloud> mid = [
    (x: 352, y: -330, width: 150),
    (x: 330, y: -760, width: 130),
    (x: 40, y: -1180, width: 150),
    (x: 350, y: -1560, width: 160),
  ];
  static const double midSlide = 0.62;
  static const double midDrift = 9;

  /// Near clouds: white, centred off the edges so a part shows, faster than
  /// the ground and in front of him.
  static const List<CloudClimbCloud> near = [
    (x: 478, y: -700, width: 300),
    (x: -106, y: -1500, width: 320),
    (x: 486, y: -2350, width: 340),
    (x: -100, y: -3050, width: 300),
  ];
  static const double nearSlide = 1.55;
  static const double nearDrift = 14;

  /// How far a cloud's height is of its width.
  static const double farRatio = 0.34;
  static const double midRatio = 0.36;
  static const double nearRatio = 0.36;

  static Offset starAt(int i, double t, Size size) {
    final star = stars[i];
    return Offset(star.x + _across(size), star.y + rise(t) * star.slide);
  }

  static Offset farAt(int i, double t, Size size) {
    final cloud = far[i];
    return Offset(
      cloud.x + _across(size) + t * farDrift,
      cloud.y + rise(t) * farSlide,
    );
  }

  static Offset midAt(int i, double t, Size size) {
    final cloud = mid[i];
    return Offset(
      cloud.x + _across(size) - t * midDrift,
      cloud.y + rise(t) * midSlide,
    );
  }

  /// A near cloud hangs off the side it began on and drifts inwards.
  static Offset nearAt(int i, double t, Size size) {
    final cloud = near[i];
    final isLeft = cloud.x < _designWidth / 2;
    final x = cloud.x + (isLeft ? 0 : size.width - _designWidth);
    return Offset(
      x + (isLeft ? 1 : -1) * t * nearDrift,
      cloud.y + rise(t) * nearSlide,
    );
  }

  /// The whole of a near cloud: the pill and its bumps.
  static Rect nearBox(int i, double t, Size size) {
    final width = near[i].width;
    final height = width * nearRatio;
    final c = nearAt(i, t, size);
    return Rect.fromLTRB(
      c.dx - width / 2,
      c.dy - height * 0.56,
      c.dx + width / 2,
      c.dy + height * 0.5,
    );
  }

  /// The near clouds thin out as the moon grows.
  static double nearAlpha(double t) =>
      1 - sine(phase(moonProgress(t), 0.45, 0.85));

  // ---- the words

  /// One line, two rows, in the sky.
  static double wordsAlpha(double t) =>
      sine(phase(t, 1.25, 1.75)) * (1 - sine(phase(t, 2.6, 3)));

  /// How far the words have drifted down.
  static double wordsDrop(double t) => math.max(0, t - 1.25) * 9;

  /// The line in two rows, split at the last space.
  static (String, String) splitWords(String words) {
    final at = words.lastIndexOf(' ');
    if (at < 0) return (words, '');
    return (words.substring(0, at), words.substring(at + 1));
  }

  // ---- the moon

  /// How far the moon has come, 0 to 1.
  static double moonProgress(double t) => sine(phase(t, 2, 3.6));

  static Offset moonCentre(double t, Size size) {
    final mp = moonProgress(t);
    final across = _across(size);
    return Offset(
      _lerp(262 + across, size.width / 2, mp),
      _lerp(-130, size.height * 300 / 844, mp),
    );
  }

  /// The moon grows by the square of its progress until it covers every
  /// corner of the screen.
  static double moonRadius(double t, Size size) {
    final mp = moonProgress(t);
    final centre = Offset(size.width / 2, size.height * 300 / 844);
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final full = math.max<double>(
      640,
      corners.map((c) => (c - centre).distance).reduce(math.max) + 8,
    );
    return _lerp(64, full, mp * mp);
  }

  /// The thin ring round the moon fades as it grows.
  static double moonRingAlpha(double t) => 0.5 * (1 - moonProgress(t));

  // ---- the last frame

  /// How far the outro's last frame has faded out, 0 at [uncover] and 1 at
  /// [end].
  static double fadeOut(double t) => phase(t, uncover, end);

  // ---- Crit

  /// Where his mascot starts with none to start from.
  static Rect stageBox(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.42),
    width: 150,
    height: 150,
  );

  /// Where he floats while he sleeps.
  static Rect hoverBox(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, math.min(450, size.height * 0.56)),
    width: 170,
    height: 170,
  );

  static double _settle(double t) => sine(phase(t, 0.35, 1.5));
  static double _lift(double t) => sine(phase(t, 3.15, 3.85));
  static double _float(double t) => (1 - _lift(t)) * sine(phase(t, 0.5, 1.4));

  /// His box at [t]: from [mascot] (the stage with none) to the hover, then
  /// to [land], where it ends exactly.
  static Rect critBox(
    double t, {
    required Size size,
    required Rect land,
    Rect? mascot,
  }) {
    final start = mascot ?? stageBox(size);
    final hover = hoverBox(size);
    final settle = _settle(t);
    final lift = _lift(t);
    final bob = math.sin(t * 1.7) * 6 * _float(t);
    final centre = _lerpOffset(
      _lerpOffset(start.center, hover.center, settle),
      land.center,
      lift,
    );
    final width = _lerp(
      _lerp(start.width, hover.width, settle),
      land.width,
      lift,
    );
    final height = _lerp(
      _lerp(start.height, hover.height, settle),
      land.height,
      lift,
    );
    return Rect.fromCenter(
      center: centre.translate(0, bob),
      width: width,
      height: height,
    );
  }

  /// His tilt, in radians. Upright once he is up.
  static double angle(double t) {
    const degree = math.pi / 180;
    return (4 * degree * sine(phase(t, 0.6, 1.3)) +
            math.sin(t * 1.3) * 2 * degree * _float(t)) *
        (1 - sine(phase(t, 3, 3.5)));
  }

  /// His height against his rest height: a small squash into the yawn and a
  /// small stretch as he wakes. One at rest.
  static double stretch(double t) =>
      1 +
      0.06 * sine(phase(t, 0.2, 0.35)) * (1 - sine(phase(t, 0.35, 0.5))) +
      0.07 * sine(phase(t, 3.45, 3.6)) * (1 - sine(phase(t, 3.6, 3.8)));

  static const List<({double at, HeroFace face})> _faces = [
    (at: 0, face: HeroFace.glad),
    // The yawn.
    (at: 0.2, face: HeroFace.relieved),
    (at: 0.5, face: HeroFace.glad),
    // Asleep, then a sleepy smile: eyes shut.
    (at: 0.75, face: HeroFace.listening),
    // He wakes straight to glad, with no wide-eyed face between.
    (at: 3.3, face: HeroFace.glad),
  ];

  /// His face: each turn blends into the next over [heroFaceBlend].
  static ThanksFace face(double t) {
    var index = 0;
    for (var i = 0; i < _faces.length; i++) {
      if (t >= _faces[i].at) index = i;
    }
    final turn = _faces[index];
    final from = _faces[math.max(0, index - 1)].face;
    return (
      from: from,
      to: turn.face,
      blend: index == 0 ? 1 : phase(t, turn.at, turn.at + heroFaceBlend),
    );
  }

  // ---- his cloud

  /// His cloud grows from nothing.
  static double cloudGrow(double t) => sine(phase(t, 0.12, 0.7));

  /// His cloud melts into the ground colour.
  static double cloudMelt(double t) => sine(phase(t, 3.35, 3.8));

  /// How much of his cloud is there.
  static double cloudAlpha(double t) => cloudGrow(t) * (1 - cloudMelt(t));

  /// The box on the cloud fades in, and out before the cloud melts.
  static double boxAlpha(double t) =>
      sine(phase(t, 0.7, 1.1)) * (1 - sine(phase(t, 3.3, 3.5)));

  /// The two dots glow in turn on a smooth sine, never on and off.
  static CloudClimbGlow glow(double t) {
    final g = (math.sin(t * 2.4) + 1) / 2;
    return (a: _lerp(0.25, 1, g), b: _lerp(0.25, 1, 1 - g));
  }

  /// How solid trail disc [i] is. How far it hangs back follows [speed], so
  /// both are gone when he is still.
  static double trailAlpha(double t, int i) =>
      0.55 * speed(t) * (1 - i * 0.28) * (1 - cloudMelt(t));

  /// How far trail disc [i] hangs under the cloud.
  static double trailDrop(double t, int i) => (i + 1) * 34 * speed(t);
}
