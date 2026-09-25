part of 'onboarding_welcome_screen.dart';

// Three more face heroes: the orbit with the app's features going round it,
// a parade that is angry rather than cute, and an orbit of ringing faces.

// ---------------------------------------------------------------------------
// 13. Feature orbit.

/// One thing Crit Alarm does, as a chip going round the face.
class _Feature {
  const _Feature(this.labelKey, this.icon);

  final String labelKey;
  final Widget Function(Color ink) icon;
}

Widget _glyphIcon(GlyphType glyph, Color ink) =>
    AppGlyph(glyph, color: ink, strokeWidth: 2.8);

/// Four little tiles, a home screen in miniature.
Widget _widgetsIcon(Color ink) => SizedBox.square(
  dimension: 14,
  child: GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 2,
    crossAxisSpacing: 2,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    children: [
      for (var i = 0; i < 4; i++)
        DecoratedBox(
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  ),
);

Widget _promptIcon(Color ink) => Text(
  '>_',
  style: TextStyle(
    fontFamily: AppTypography.fontMono,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w700,
    color: ink,
  ),
);

final List<_Feature> _features = [
  const _Feature(LocaleKeys.onboarding_welcome_feature_widgets, _widgetsIcon),
  _Feature(
    LocaleKeys.onboarding_welcome_feature_alarm,
    (ink) => _glyphIcon(GlyphType.bell, ink),
  ),
  const _Feature(LocaleKeys.onboarding_welcome_feature_curl, _promptIcon),
  _Feature(
    LocaleKeys.onboarding_welcome_feature_priority,
    (ink) => _glyphIcon(GlyphType.up, ink),
  ),
  _Feature(
    LocaleKeys.onboarding_welcome_feature_ack,
    (ink) => _glyphIcon(GlyphType.check, ink),
  ),
  _Feature(
    LocaleKeys.onboarding_welcome_feature_sounds,
    (ink) => _glyphIcon(GlyphType.play, ink),
  ),
  _Feature(
    LocaleKeys.onboarding_welcome_feature_history,
    (ink) => _glyphIcon(GlyphType.clock, ink),
  ),
  _Feature(
    LocaleKeys.onboarding_welcome_feature_search,
    (ink) => _glyphIcon(GlyphType.search, ink),
  ),
];

class _FeatureOrbitHero extends StatefulWidget {
  const _FeatureOrbitHero();

  @override
  State<_FeatureOrbitHero> createState() => _FeatureOrbitHeroState();
}

class _FeatureOrbitHeroState extends _ClockState<_FeatureOrbitHero> {
  @override
  double get restAt => 3;

  /// Radians a second the ring turns.
  static const double _spin = 0.42;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final faceSize = math.min(w * 0.36, h * 0.3);
        // A ring seen from a little above, so the chips pass in front of
        // the face at the bottom and behind it at the top. It rocks slowly,
        // like it is afloat.
        final rx = w / 2 - _chipWidth / 2;
        final ry = math.min(h / 2 - 44, rx * 1.05);
        final tilt = math.sin(t * 0.35) * 0.12;
        final cosT = math.cos(tilt);
        final sinT = math.sin(tilt);

        final chips = <(double, Widget)>[];
        var frontZ = -1.0;
        var frontX = 0.0;
        for (var i = 0; i < _features.length; i++) {
          final out = Curves.easeOutBack.transform(
            _window(t, 0.55 + i * 0.09, 0.9),
          );
          // They spiral out from behind the face as they arrive.
          final angle =
              i * 2 * math.pi / _features.length +
              t * _spin +
              (1 - out) * math.pi * 0.8;
          final z = math.sin(angle);
          final ex = math.cos(angle) * rx * out;
          final ey = z * ry * out;
          final x = ex * cosT - ey * sinT;
          final y = ex * sinT + ey * cosT;
          if (out > 0.9 && z > frontZ) {
            frontZ = z;
            frontX = x / rx;
          }
          final depth = (z + 1) / 2;
          // Chips at the sides of the ring are nearest the face, so they
          // shrink a touch there to keep clear of it.
          final side = math.cos(angle).abs();
          chips.add((
            z,
            Transform.translate(
              offset: Offset(x, y),
              child: Opacity(
                opacity: (out * (0.4 + 0.6 * depth)).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale:
                      (0.62 + 0.42 * depth - 0.08 * side) * (0.4 + 0.6 * out),
                  child: _chip(
                    _features[i],
                    _crowdFills[i % _crowdFills.length],
                    colors,
                    // The chip nearest the viewer gets a little lift.
                    glow: math.max(0, (z - 0.9) / 0.1),
                    spin: t * 1.4 + i,
                  ),
                ),
              ),
            ),
          ));
        }
        chips.sort((a, b) => a.$1.compareTo(b.$1));

        // The face watches whichever chip is at the front, and lights up
        // as each one passes right under its nose.
        final gaze = frontX.clamp(-1.0, 1.0);
        final look = gaze < 0
            ? _blend(FaceState.calm, FaceState.lookLeft, -gaze)
            : _blend(FaceState.calm, FaceState.lookRight, gaze);
        final delight = Curves.easeOut.transform(
          ((frontZ - 0.94) / 0.06).clamp(0.0, 1.0),
        );
        final mood = _delightFor(t);
        final face = t < 1.4
            ? _shape(FaceState.happy)
            : _withBlink(FaceShape.lerp(look, _shape(mood), delight), t);

        final pop = Curves.easeOutBack.transform(_window(t, 0, 0.7));
        final breathe = math.sin(t * 2.4) * 0.02;
        final hop = -math.sin(delight * math.pi / 2) * 8;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _OrbitBackdropPainter(
                  t: t,
                  rx: rx,
                  ry: ry,
                  tilt: tilt,
                  faceRadius: faceSize / 2,
                  ring: colors.onCanvas,
                  glow: colors.yellow,
                ),
              ),
            ),
            for (final c in chips)
              if (c.$1 < 0) c.$2,
            Transform.translate(
              offset: Offset(0, hop),
              child: Transform.scale(
                scale: pop + breathe + delight * 0.05,
                child: _face(face, faceSize),
              ),
            ),
            for (final c in chips)
              if (c.$1 >= 0) c.$2,
          ],
        );
      },
    );
  }

  static const double _chipWidth = 96;

  /// A different grin for each chip that goes past.
  FaceState _delightFor(double t) {
    const moods = [
      FaceState.happy,
      FaceState.love,
      FaceState.interested,
      FaceState.proud,
      FaceState.cheeky,
      FaceState.laughing,
    ];
    final pass = (t * _spin / (2 * math.pi / _features.length)).floor();
    return moods[pass % moods.length];
  }

  /// A bubble with the feature's icon in it and its name underneath.
  Widget _chip(
    _Feature feature,
    Color fill,
    AppColors colors, {
    required double glow,
    required double spin,
  }) => SizedBox(
    width: _chipWidth,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          // A little rock, and a proper wiggle as it passes the face.
          angle: math.sin(spin) * 0.12 + math.sin(spin * 6) * 0.2 * glow,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: _darkInk, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x33000000),
                  blurRadius: 8 + glow * 12,
                  offset: Offset(0, 3 + glow * 5),
                ),
                if (glow > 0)
                  BoxShadow(
                    color: fill.withValues(alpha: 0.7 * glow),
                    blurRadius: 18,
                    spreadRadius: 4 * glow,
                  ),
              ],
            ),
            child: Transform.scale(scale: 1.35, child: feature.icon(_darkInk)),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.fullAll,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            feature.labelKey.tr(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: colors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The ring the chips ride on, a warm glow behind the face, a shockwave as
/// the face arrives, and a few sparkles.
class _OrbitBackdropPainter extends CustomPainter {
  const _OrbitBackdropPainter({
    required this.t,
    required this.rx,
    required this.ry,
    required this.tilt,
    required this.faceRadius,
    required this.ring,
    required this.glow,
  });

  final double t;
  final double rx;
  final double ry;
  final double tilt;
  final double faceRadius;
  final Color ring;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Glow, breathing.
    final glowR = faceRadius * (1.9 + math.sin(t * 2.4) * 0.12);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.45 * _window(t, 0, 0.8)),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // Shockwave as the face lands.
    final wave = _window(t, 0.1, 0.9);
    if (wave > 0 && wave < 1) {
      canvas.drawCircle(
        c,
        faceRadius * (0.8 + wave * 2.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - wave)
          ..color = glow.withValues(alpha: 1 - wave),
      );
    }

    // The ring, drawn out as the chips arrive.
    final draw = Curves.easeInOutCubic.transform(_window(t, 0.4, 1.4));
    if (draw > 0) {
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(tilt);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: rx * 2,
        height: ry * 2,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring.withValues(alpha: 0.18);
      canvas
        ..drawArc(rect, math.pi / 2, 2 * math.pi * draw, false, paint)
        ..drawArc(
          rect.inflate(14),
          -math.pi / 2,
          2 * math.pi * draw,
          false,
          paint..color = ring.withValues(alpha: 0.08),
        )
        ..restore();
    }

    // Sparkles, each twinkling to its own beat.
    for (var i = 0; i < 14; i++) {
      final seed = i * 97.31;
      final x = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final y = (math.cos(seed * 1.7) * 0.5 + 0.5) * size.height;
      final tw = math.sin(t * (1.6 + i % 5 * 0.4) + seed);
      if (tw <= 0.2) continue;
      final s = 2 + 5 * (tw - 0.2);
      _star(
        canvas,
        Offset(x, y),
        s,
        _crowdFills[i % _crowdFills.length].withValues(
          alpha: (tw - 0.2) * _window(t, 1, 1),
        ),
      );
    }
  }

  static void _star(Canvas canvas, Offset at, double r, Color color) {
    final path = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OrbitBackdropPainter old) => true;
}

// ---------------------------------------------------------------------------
// 14. Angry parade.

class _AngryParadeHero extends StatefulWidget {
  const _AngryParadeHero();

  @override
  State<_AngryParadeHero> createState() => _AngryParadeHeroState();
}

class _AngryParadeHeroState extends _ClockState<_AngryParadeHero> {
  @override
  double get restAt => 2.4;

  static const List<FaceState> _moods = [
    FaceState.determined,
    FaceState.alarmed,
    FaceState.skeptical,
    FaceState.shocked,
    FaceState.concerned,
    FaceState.confident,
  ];

  static const int _count = 5;

  /// When face [i] lands from its drop.
  static double _landAt(int i) => 0.15 * i + 0.5;

  /// How far into the current stomp face [i] is, or null before the stomps
  /// start. Everyone stomps in turn, left to right, every 2.2 seconds.
  static double? _stomp(int i, double t) {
    final start = 1.6 + i * 0.12;
    if (t < start) return null;
    return (t - start) % 2.2;
  }

  /// How hard the ground is shaking: a kick on every landing, dying away.
  double _rumble(double t) {
    var r = 0.0;
    for (var i = 0; i < _count; i++) {
      final land = t - _landAt(i);
      if (land >= 0 && land < 0.35) r += 1 - land / 0.35;
      final s = _stomp(i, t);
      if (s != null && s >= 0.42 && s < 0.72) r += 1 - (s - 0.42) / 0.3;
    }
    return r.clamp(0.0, 1.6);
  }

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final size = math.min<double>(
          72,
          (box.maxWidth - gap * (_count - 1)) / _count,
        );
        final rumble = _rumble(t);
        final shake = Offset(
          math.sin(t * 71) * 4 * rumble,
          math.cos(t * 59) * 2.5 * rumble,
        );
        return Transform.translate(
          offset: shake,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _count; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  _member(i, size, t, box.maxHeight, colors),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _member(
    int i,
    double size,
    double t,
    double height,
    AppColors colors,
  ) {
    // The drop: falls in from above the hero, gathering speed.
    final land = _landAt(i);
    final fall = Curves.easeInQuad.transform(_window(t, land - 0.45, 0.45));
    var y = -(1 - fall) * (height / 2 + size);

    // Squash on impact, then spring back.
    var squash = 0.0;
    final sinceLand = t - land;
    if (sinceLand >= 0 && sinceLand < 0.4) {
      squash = math.sin(sinceLand / 0.4 * math.pi) * (1 - sinceLand / 0.4);
    }

    // Then a stomp: crouch, leap, slam.
    var vein = 0.0;
    var dust = -1.0;
    if (sinceLand >= 0 && sinceLand < 0.6) dust = sinceLand / 0.6;
    final s = _stomp(i, t);
    if (s != null) {
      if (s < 0.1) {
        squash = s / 0.1 * 0.5;
      } else if (s < 0.3) {
        final up = Curves.easeOutCubic.transform((s - 0.1) / 0.2);
        y = -34 * up;
        squash = -0.35 * up;
      } else if (s < 0.42) {
        final down = Curves.easeInCubic.transform((s - 0.3) / 0.12);
        y = -34 * (1 - down);
        squash = -0.35 * (1 - down);
      } else if (s < 0.8) {
        final p = (s - 0.42) / 0.38;
        squash = math.sin(p * math.pi) * (1 - p) * 1.1;
      }
      if (s >= 0.42 && s < 1.4) {
        vein = (s - 0.42) / 0.98;
        dust = (s - 0.42) / 0.6;
      }
    }

    // A tremble of fury the whole time.
    final tremble = sinceLand > 0 ? math.sin(t * 43 + i * 2.1) * 1.4 : 0.0;

    final face = _withBlink(
      _cycle(_moods, t + i * 0.9, hold: 1.4, blend: 0.3),
      t,
      offset: i * 1.1,
    );
    final sx = 1 + squash * 0.28;
    final sy = 1 - squash * 0.3;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FumePainter(
                t: t,
                seed: i,
                steam: _window(t, land + 0.2, 0.6),
                vein: vein,
                dust: dust,
                lift: y,
                steamColor: colors.onCanvasMuted,
                veinColor: colors.crit,
                dustColor: colors.onCanvas,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(tremble, y),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(sx, sy, 1),
              child: _face(
                face,
                size,
                fill: _crowdFills[i % _crowdFills.length],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Steam off both sides of an angry head, the throbbing vein on a stomp,
/// and dust kicked up where it lands.
class _FumePainter extends CustomPainter {
  const _FumePainter({
    required this.t,
    required this.seed,
    required this.steam,
    required this.vein,
    required this.dust,
    required this.lift,
    required this.steamColor,
    required this.veinColor,
    required this.dustColor,
  });

  final double t;
  final int seed;

  /// 0 to 1, how much steam is coming off.
  final double steam;

  /// 0 to 1 through the vein popping and fading, 0 for none.
  final double vein;

  /// 0 to 1 through the dust cloud, anything outside that for none.
  final double dust;

  /// How far the head is off the ground, so the steam follows it.
  final double lift;

  final Color steamColor;
  final Color veinColor;
  final Color dustColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = lift + w * 0.18;

    if (steam > 0) {
      for (final side in [-1.0, 1.0]) {
        for (var k = 0; k < 3; k++) {
          final life =
              (t * 1.4 + k / 3 + seed * 0.23 + (side > 0 ? 0.5 : 0)) % 1.0;
          final x = w / 2 + side * (w * 0.42 + life * w * 0.28);
          final y = top - life * w * 0.55;
          canvas.drawCircle(
            Offset(x, y),
            w * (0.04 + life * 0.09),
            Paint()
              ..color = steamColor.withValues(
                alpha: 0.55 * steam * math.sin(life * math.pi),
              ),
          );
        }
      }
    }

    if (vein > 0 && vein < 1) {
      final pop = vein < 0.25
          ? Curves.easeOutBack.transform(vein / 0.25)
          : 1 + math.sin((vein - 0.25) * 30) * 0.08;
      final fade = vein > 0.7 ? 1 - (vein - 0.7) / 0.3 : 1.0;
      final r = w * 0.14 * pop;
      final c = Offset(w * 0.86, lift + w * 0.08);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(2, w * 0.05)
        ..color = veinColor.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(0.3);
      // Four corners bent in towards the middle: the cartoon anger mark.
      for (var q = 0; q < 4; q++) {
        final g = r * 0.28;
        canvas
          ..drawPath(
            Path()
              ..moveTo(g, r)
              ..quadraticBezierTo(g, g, r, g),
            paint,
          )
          ..rotate(math.pi / 2);
      }
      canvas.restore();
    }

    if (dust >= 0 && dust < 1) {
      final floor = w;
      for (var k = 0; k < 4; k++) {
        final side = k.isEven ? -1.0 : 1.0;
        final reach = w * (0.35 + 0.1 * k) * Curves.easeOut.transform(dust);
        canvas.drawCircle(
          Offset(w / 2 + side * reach, floor - dust * w * 0.12 * (1 + k % 2)),
          w * (0.05 + 0.05 * dust),
          Paint()..color = dustColor.withValues(alpha: 0.28 * (1 - dust)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FumePainter old) => true;
}

// ---------------------------------------------------------------------------
// 15. Ringing orbit.

class _RingingOrbitHero extends StatefulWidget {
  const _RingingOrbitHero();

  @override
  State<_RingingOrbitHero> createState() => _RingingOrbitHeroState();
}

class _RingingOrbitHeroState extends _ClockState<_RingingOrbitHero> {
  @override
  double get restAt => 2;

  static const List<RingingStyle> _moons = [
    RingingStyle.rage,
    RingingStyle.panic,
    RingingStyle.bellHead,
    RingingStyle.siren,
    RingingStyle.scream,
    RingingStyle.zapped,
    RingingStyle.eyesPop,
    RingingStyle.terrified,
  ];

  /// One ring of the bell every this many seconds.
  static const double _beat = 0.62;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight);
        final big = side * 0.52;
        final small = side * 0.26;
        final radius = side / 2 - small * 0.4;

        // Every beat kicks the ring outwards and rattles the whole stage.
        final since = t < 0.8 ? 1.0 : ((t - 0.8) % _beat) / _beat;
        final kick = math.pow(1 - since, 3).toDouble();
        final rattle = Offset(
          math.sin(t * 83) * 3.5 * kick,
          math.cos(t * 67) * 2.5 * kick,
        );

        final centreIn = Curves.elasticOut.transform(_window(t, 0, 1.1));

        return Transform.translate(
          offset: rattle,
          child: Center(
            child: SizedBox.square(
              dimension: side,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AlarmWavesPainter(
                        t: t,
                        beat: _beat,
                        inner: big * 0.3,
                        outer: side * 0.62,
                        color: colors.crit,
                      ),
                    ),
                  ),
                  for (var i = 0; i < _moons.length; i++)
                    _moon(i, t, radius, small, kick, side),
                  Transform.scale(
                    scale: centreIn * (1 + kick * 0.06),
                    child: RingingFaceWidget(
                      style: RingingStyle.classic,
                      size: big,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moon(
    int i,
    double t,
    double radius,
    double size,
    double kick,
    double side,
  ) {
    // Flung in from off stage, spinning, then round and round.
    final out = Curves.easeOutBack.transform(_window(t, 0.25 + i * 0.07, 0.8));
    final angle =
        i * 2 * math.pi / _moons.length +
        t * 0.7 -
        math.pi / 2 -
        (1 - out) * math.pi;
    final r = side * (1 - out) + radius * out + kick * 8;
    final wobble = math.sin(t * 5 + i * 1.3) * 0.08;
    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
      child: Opacity(
        opacity: _window(t, 0.25 + i * 0.07, 0.3),
        child: Transform.rotate(
          angle: (1 - out) * math.pi * 2 + wobble,
          child: Transform.scale(
            scale: 1 + math.sin(t * 6 + i) * 0.06,
            child: RingingFaceWidget(
              style: _moons[i],
              size: size,
              fillColor: _crowdFills[i % _crowdFills.length],
              inkColor: _darkInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sound going out from the middle, one ring per beat, over a red glow that
/// flares on every hit.
class _AlarmWavesPainter extends CustomPainter {
  const _AlarmWavesPainter({
    required this.t,
    required this.beat,
    required this.inner,
    required this.outer,
    required this.color,
  });

  final double t;
  final double beat;
  final double inner;
  final double outer;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final on = _window(t, 0.6, 0.6);
    if (on <= 0) return;

    final since = ((t - 0.8) % beat) / beat;
    final flare = t < 0.8 ? 0.0 : math.pow(1 - since, 2).toDouble();
    canvas.drawCircle(
      c,
      outer * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: (0.18 + 0.22 * flare) * on),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: outer * 0.75)),
    );

    // Three waves in flight at once, each a beat apart.
    for (var k = 0; k < 3; k++) {
      final p = (t / beat + k / 3) % 1.0;
      final r = inner + (outer - inner) * Curves.easeOut.transform(p);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - p) + 1
          ..color = color.withValues(alpha: 0.55 * (1 - p) * on),
      );
    }

    // Little zigzag bolts sparking off the waves.
    final bolt = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: flare * on);
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3 + (t ~/ beat) * 0.5;
      final r0 = inner * 1.35;
      final r1 = r0 + 18 * flare;
      final dir = Offset(math.cos(a), math.sin(a));
      final norm = Offset(-dir.dy, dir.dx);
      final mid = (r0 + r1) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + dir.dx * r0, c.dy + dir.dy * r0)
          ..lineTo(
            c.dx + dir.dx * mid + norm.dx * 5,
            c.dy + dir.dy * mid + norm.dy * 5,
          )
          ..lineTo(
            c.dx + dir.dx * mid - norm.dx * 5,
            c.dy + dir.dy * mid - norm.dy * 5,
          )
          ..lineTo(c.dx + dir.dx * r1, c.dy + dir.dy * r1),
        bolt,
      );
    }
  }

  @override
  bool shouldRepaint(_AlarmWavesPainter old) => true;
}
