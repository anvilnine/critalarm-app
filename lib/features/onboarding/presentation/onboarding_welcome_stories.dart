part of 'onboarding_welcome_screen.dart';

// The welcome heroes that show how Crit Alarm works, rather than only the
// faces. The phone screens follow the site's hero demo
// (critalarm-site/src/components/DemoFrame.astro). They are drawn at a full
// 390 x 844 and scaled down to fit, so every size in here is a real phone
// size.

/// Fully shown between [start] and [end], fading in and out over [fade].
double _shown(double t, double start, double end, {double fade = 0.3}) =>
    math.min(_window(t, start, fade), 1 - _window(t, end, fade));

/// A quick press and release centred on [at].
double _press(double t, double at) =>
    math.sin(_window(t, at - 0.15, 0.3) * math.pi);

String _secs(String key, int seconds) =>
    key.tr(namedArgs: {'seconds': '$seconds'});

/// [child] faded to [o] and slid in from [from] as it arrives.
Widget _layer(double o, Widget child, {Offset from = Offset.zero}) {
  if (o <= 0) return const SizedBox.shrink();
  return Opacity(
    opacity: o.clamp(0.0, 1.0),
    child: Transform.translate(offset: from * (1 - o), child: child),
  );
}

const Color _white = Color(0xFFFFFFFF);
const Color _screenBlack = Color(0xFF0E0E10);
const Color _yellow = Color(0xFFFFC93C);
const Color _grey = Color(0xFF8E8E93);

const String _curl =
    'curl https://api.critalarm.app/prod-db \\\n'
    '  -H "Authorization: Bearer tk_7Hq2mN9x" \\\n'
    '  -H "Priority: 5" \\\n'
    '  -d "Primary database down"';

// ---------------------------------------------------------------------------
// Phone parts.

/// A phone drawn at full size and scaled to whatever room it gets.
class _MiniPhone extends StatelessWidget {
  const _MiniPhone({
    required this.screen,
    this.isAndroid = false,
    this.island = 0,
  });

  final Widget screen;
  final bool isAndroid;

  /// 0 is the resting Dynamic Island, 1 is stretched to hold a face and a
  /// bell, which is what a ringing Crit Alarm does to it.
  final double island;

  static const double _w = 390;
  static const double _h = 844;
  static const double _bezel = 14;

  @override
  Widget build(BuildContext context) {
    final radius = isAndroid ? 44.0 : 58.0;
    return AspectRatio(
      aspectRatio: (_w + 2 * _bezel) / (_h + 2 * _bezel),
      child: FittedBox(
        child: Container(
          width: _w + 2 * _bezel,
          height: _h + 2 * _bezel,
          padding: const EdgeInsets.all(_bezel),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1917),
            borderRadius: BorderRadius.circular(radius + _bezel),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: _w,
              height: _h,
              child: Stack(
                children: [
                  Positioned.fill(child: screen),
                  Positioned(
                    top: 18,
                    left: isAndroid ? 30 : 46,
                    child: const Text(
                      '3:12',
                      style: TextStyle(
                        color: _white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    top: isAndroid ? 16 : 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: isAndroid
                          ? _punchHole()
                          : _dynamicIsland(context.appColors.crit),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _punchHole() => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(
      color: _screenBlack,
      shape: BoxShape.circle,
    ),
  );

  Widget _dynamicIsland(Color bell) {
    final wide = Curves.easeOutBack.transform(island.clamp(0.0, 1.0));
    return Container(
      width: 124 + 96 * wide,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _screenBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Opacity(
        opacity: island.clamp(0.0, 1.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const FaceWidget(
              state: FaceState.alarmed,
              size: 24,
              overrideFillColor: _yellow,
              overrideStrokeColor: _yellow,
              overrideInkColor: _darkInk,
            ),
            Icon(Icons.notifications, color: bell, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A fingertip that hovers over [at], then presses by [press].
Widget _finger(Offset at, double o, double press) => Positioned(
  left: at.dx - 36,
  top: at.dy - 36,
  child: _layer(
    o,
    Transform.scale(
      scale: 1 - 0.25 * press,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _white.withValues(alpha: 0.45 + 0.3 * press),
          border: Border.all(color: _white.withValues(alpha: 0.9), width: 2),
        ),
      ),
    ),
  ),
);

class _IosLock extends StatelessWidget {
  const _IosLock({this.children = const []});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'EEEE d MMMM',
      context.locale.toString(),
    ).format(DateTime(2026, 9, 24));
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF14121C))),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.9, -0.9),
                radius: 1.1,
                colors: [Color(0x992A3BD8), Color(0x002A3BD8)],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.9, 0.95),
                radius: 0.9,
                colors: [Color(0x66B08A22), Color(0x00B08A22)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 64,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: _white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                '3:12',
                style: TextStyle(
                  color: _white,
                  fontSize: 108,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 46,
          bottom: 52,
          child: _lockButton(Icons.flashlight_on),
        ),
        Positioned(
          right: 46,
          bottom: 52,
          child: _lockButton(Icons.photo_camera_outlined),
        ),
        ...children,
      ],
    );
  }

  static Widget _lockButton(IconData icon) => Container(
    width: 54,
    height: 54,
    decoration: const BoxDecoration(
      color: Color(0x33FFFFFF),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: _white, size: 24),
  );
}

class _IosNotice extends StatelessWidget {
  const _IosNotice();

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF6E6E73);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE6E9E9EE),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _appIcon(46, context.appColors.crit),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      LocaleKeys.app_title.tr().toUpperCase(),
                      style: const TextStyle(
                        color: grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      LocaleKeys.onboarding_welcome_story_now.tr(),
                      style: const TextStyle(color: grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${LocaleKeys.onboarding_welcome_story_critical.tr()}'
                  ' · prod-db',
                  style: const TextStyle(
                    color: _darkInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
                  style: const TextStyle(color: _darkInk, fontSize: 17),
                ),
                Text(
                  LocaleKeys.onboarding_welcome_story_until_ack.tr(),
                  style: const TextStyle(color: grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The app icon: a ringing face on a tile of [fill].
Widget _appIcon(double size, Color fill, {bool round = false}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(round ? size / 2 : size * 0.26),
  ),
  child: Center(
    child: FaceWidget(
      state: FaceState.alarmed,
      size: size * 0.7,
      overrideFillColor: _yellow,
      overrideStrokeColor: _darkInk,
      overrideInkColor: _darkInk,
    ),
  ),
);

/// The Live Activity card on the lock screen, ringing.
class _LiveActivity extends StatelessWidget {
  const _LiveActivity({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final crit = context.appColors.crit;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6E9E9EE),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          FaceWidget(
            state: FaceState.alarmed,
            size: 64,
            isLive: true,
            overrideFillColor: crit,
            overrideStrokeColor: crit,
            overrideInkColor: _darkInk,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'prod-db',
                      style: AppTypography.mono(const Color(0xFF6E6E73)),
                    ),
                    const SizedBox(width: 8),
                    _badge(
                      LocaleKeys.onboarding_welcome_story_ringing.tr(),
                      crit,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
                  style: const TextStyle(
                    color: _darkInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _secs(LocaleKeys.onboarding_welcome_story_seconds, seconds),
                  style: const TextStyle(
                    color: Color(0xFF6E6E73),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small filled label, like RINGING or AWAKE.
Widget _badge(String label, Color fill, {Color text = _white}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text(
    label,
    style: TextStyle(
      color: text,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    ),
  ),
);

/// Where "I'm up" sits on [_AlarmKitAlert], for the finger to find.
const Offset _systemImUp = Offset(195, 620);

/// The system alarm AlarmKit puts over everything. "I'm up" here opens the
/// app, which keeps ringing until "I'm up" is tapped there too.
class _AlarmKitAlert extends StatelessWidget {
  const _AlarmKitAlert({required this.press});

  final double press;

  @override
  Widget build(BuildContext context) {
    final crit = context.appColors.crit;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Column(
        children: [
          const SizedBox(height: 150),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, color: _grey, size: 28),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
                style: const TextStyle(color: _grey, fontSize: 22),
              ),
            ],
          ),
          const Text(
            '3:12',
            style: TextStyle(
              color: _white,
              fontSize: 124,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          Text(
            LocaleKeys.app_title.tr(),
            style: const TextStyle(color: _grey, fontSize: 16),
          ),
          const Spacer(),
          Transform.scale(
            scale: 1 - 0.05 * press,
            child: Container(
              width: 340,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(crit, _darkInk, press * 0.2),
                borderRadius: BorderRadius.circular(46),
              ),
              child: Text(
                LocaleKeys.onboarding_welcome_story_im_up.tr(),
                style: const TextStyle(
                  color: _white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 340,
            height: 92,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(46),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  LocaleKeys.onboarding_welcome_story_slide_to_stop.tr(),
                  style: const TextStyle(color: _grey, fontSize: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

/// Where "I'm up" sits on [_AppAlarm], for the finger to find.
const Offset _appImUp = Offset(195, 696);

/// Crit Alarm's own ringing screen. Android's full screen alarm, and what an
/// iPhone opens into from the system alarm.
class _AppAlarm extends StatelessWidget {
  const _AppAlarm({required this.seconds, this.press = 0});

  final int seconds;
  final double press;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ColoredBox(
      color: colors.crit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: FaceWidget(
                state: FaceState.alarmed,
                size: 210,
                isLive: true,
                overrideFillColor: _yellow,
                overrideStrokeColor: _yellow,
                overrideInkColor: _darkInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.onboarding_welcome_story_critical.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.display(_darkInk, fontSize: 64),
            ),
            Text(
              'prod-db',
              textAlign: TextAlign.center,
              style: AppTypography.monoBold(_darkInk, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              _secs(LocaleKeys.onboarding_welcome_story_ringing_for, seconds),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _darkInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
                    style: const TextStyle(
                      color: _darkInk,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocaleKeys.onboarding_welcome_story_alarm_body.tr(),
                    style: const TextStyle(color: _darkInk, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'uptime-kuma / 03:12:04 / postgres, db-1',
                    style: AppTypography.monoBold(
                      const Color(0xB31A140F),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Transform.scale(
              scale: 1 - 0.05 * press,
              child: _pill(
                LocaleKeys.onboarding_welcome_story_im_up.tr(),
                fill: colors.cobalt,
                text: _white,
              ),
            ),
            const SizedBox(height: 12),
            _pill(
              LocaleKeys.onboarding_welcome_story_silence.tr(),
              text: _darkInk,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _pill(String label, {required Color text, Color? fill}) => Container(
  height: 64,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(32),
    border: fill == null ? Border.all(color: text, width: 2) : null,
  ),
  child: Text(
    label,
    style: TextStyle(
      color: text,
      fontSize: 19,
      fontWeight: FontWeight.w700,
    ),
  ),
);

class _AckScreen extends StatelessWidget {
  const _AckScreen({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Widget row(String label, String value) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EBE3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B625A), fontSize: 16),
          ),
          const Spacer(),
          Text(value, style: AppTypography.monoBold(_darkInk, fontSize: 15)),
        ],
      ),
    );

    return ColoredBox(
      color: colors.cobalt,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(64),
                ),
                child: const FaceWidget(
                  state: FaceState.acked,
                  size: 170,
                  overrideFillColor: _yellow,
                  overrideStrokeColor: _yellow,
                  overrideInkColor: _darkInk,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                LocaleKeys.onboarding_welcome_story_acknowledged.tr(),
                style: AppTypography.display(_white, fontSize: 54),
              ),
            ),
            Text(
              'prod-db',
              textAlign: TextAlign.center,
              style: AppTypography.monoBold(_white, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              _secs(LocaleKeys.onboarding_welcome_story_rang_for, seconds),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  row(
                    LocaleKeys.onboarding_welcome_story_started.tr(),
                    '03:12:04',
                  ),
                  row(
                    LocaleKeys.onboarding_welcome_story_acknowledged.tr(),
                    '03:12:${(4 + seconds).toString().padLeft(2, '0')}',
                  ),
                  row(
                    LocaleKeys.onboarding_welcome_story_source.tr(),
                    'uptime-kuma',
                  ),
                ],
              ),
            ),
            const Spacer(),
            _pill(
              LocaleKeys.onboarding_welcome_story_at_desk.tr(),
              fill: _white,
              text: _darkInk,
            ),
            const SizedBox(height: 12),
            _pill(
              LocaleKeys.onboarding_welcome_story_open_topic.tr(
                namedArgs: {'topic': 'prod-db'},
              ),
              text: _white,
            ),
          ],
        ),
      ),
    );
  }
}

class _AndroidLock extends StatelessWidget {
  const _AndroidLock();

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'EEE, d MMM',
      context.locale.toString(),
    ).format(DateTime(2026, 9, 24));
    const clock = TextStyle(
      color: Color(0xFFDCE4FF),
      fontSize: 150,
      fontWeight: FontWeight.w300,
      height: 0.95,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A4668), Color(0xFF12161F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 120,
            left: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('03', style: clock),
                const Text('12', style: clock),
                const SizedBox(height: 14),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AndroidNotice extends StatelessWidget {
  const _AndroidNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const grey = Color(0xFF5F6368);
    final action = TextStyle(
      color: colors.cobalt,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _appIcon(30, colors.crit, round: true),
              const SizedBox(width: 10),
              Text(
                '${LocaleKeys.app_title.tr()} · '
                '${LocaleKeys.onboarding_welcome_story_now.tr()}',
                style: const TextStyle(color: grey, fontSize: 14),
              ),
              const Spacer(),
              const Icon(Icons.expand_more, color: grey),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${LocaleKeys.onboarding_welcome_story_critical.tr()} · prod-db',
            style: const TextStyle(
              color: _darkInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
            style: const TextStyle(color: _darkInk, fontSize: 17),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                LocaleKeys.onboarding_welcome_story_im_up.tr().toUpperCase(),
                style: action,
              ),
              const SizedBox(width: 28),
              Text(
                LocaleKeys.onboarding_welcome_story_silence.tr().toUpperCase(),
                style: action,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rings rolling out from the middle of whatever sits on top, while
/// [isOn]. [t] drives the roll.
class _RingWaves extends StatelessWidget {
  const _RingWaves({
    required this.t,
    required this.color,
    required this.isOn,
    this.child,
  });

  final double t;
  final Color color;
  final bool isOn;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: isOn ? _RingWavesPainter(t: t, color: color) : null,
    child: child,
  );
}

class _RingWavesPainter extends CustomPainter {
  _RingWavesPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t * 0.8 + i / 3) % 1;
      canvas.drawCircle(
        centre,
        base * (0.9 + p * 1.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: (1 - p) * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingWavesPainter old) => old.t != t || old.color != color;
}

// ---------------------------------------------------------------------------
// 6. curl to alarm, laid out like the site: the phone, with the terminal
// laid over its bottom corner.

class _CurlHero extends StatefulWidget {
  const _CurlHero();

  @override
  State<_CurlHero> createState() => _CurlHeroState();
}

class _CurlHeroState extends _ClockState<_CurlHero> {
  @override
  double get restAt => 4.5;

  @override
  Widget build(BuildContext context) {
    final t = this.t % 11;
    final colors = context.appColors;
    final typed = (_window(t, 0.3, 1.9) * _curl.length).floor();
    final caretOn = (t * 2).floor().isEven || typed < _curl.length;
    final seconds = (t - 2.5).clamp(0, 99).floor() + 1;

    final mono = AppTypography.mono(_white, fontSize: 12);
    return Opacity(
      opacity: 1 - _window(t, 10.5, 0.4),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Transform.rotate(
                angle: math.sin(t * 50) * 0.012 * _shown(t, 2.5, 8.8),
                child: _MiniPhone(
                  island: _shown(t, 2.5, 8.8, fade: 0.25),
                  screen: Stack(
                    children: [
                      Positioned.fill(
                        child: _IosLock(
                          children: [
                            Positioned(
                              top: 250,
                              left: 0,
                              right: 0,
                              child: _layer(
                                _window(t, 2.5, 0.35),
                                const _IosNotice(),
                                from: const Offset(0, -40),
                              ),
                            ),
                            Positioned(
                              top: 400,
                              left: 0,
                              right: 0,
                              child: _layer(
                                _window(t, 3, 0.35),
                                _LiveActivity(seconds: seconds),
                                from: const Offset(0, 30),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: _layer(
                          _shown(t, 3.8, 6.3, fade: 0.25),
                          _AlarmKitAlert(press: _press(t, 5.8)),
                          from: const Offset(0, 60),
                        ),
                      ),
                      Positioned.fill(
                        child: _layer(
                          _shown(t, 6.2, 8.8, fade: 0.25),
                          _AppAlarm(seconds: seconds, press: _press(t, 8.4)),
                        ),
                      ),
                      Positioned.fill(
                        child: _layer(
                          _shown(t, 8.7, 20),
                          const _AckScreen(seconds: 6),
                        ),
                      ),
                      _finger(
                        _systemImUp,
                        _shown(t, 5.2, 6.1, fade: 0.2),
                        _press(t, 5.8),
                      ),
                      _finger(
                        _appImUp,
                        _shown(t, 7.8, 8.7, fade: 0.2),
                        _press(t, 8.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 24,
            bottom: 24,
            child: _layer(
              1 - _window(t, 3.4, 0.4),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1917),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        _Dot(Color(0xFF57534E)),
                        _Dot(Color(0xFF57534E)),
                        _Dot(Color(0xFF57534E)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          style: mono,
                          children: [
                            TextSpan(
                              text: r'$ ',
                              style: mono.copyWith(color: colors.yellow),
                            ),
                            TextSpan(text: _curl.substring(0, typed)),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                width: 8,
                                height: 15,
                                color: caretOn
                                    ? colors.yellow
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              from: const Offset(0, 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    margin: const EdgeInsets.only(right: 6),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ---------------------------------------------------------------------------
// 7. On an iPhone.

class _IphoneHero extends StatefulWidget {
  const _IphoneHero();

  @override
  State<_IphoneHero> createState() => _IphoneHeroState();
}

class _IphoneHeroState extends _ClockState<_IphoneHero> {
  @override
  double get restAt => 2.6;

  @override
  Widget build(BuildContext context) {
    final t = this.t % 12;
    final seconds = (t - 1).clamp(0, 99).floor() + 1;
    final ringing = _shown(t, 1, 8.8, fade: 0.25);

    return Opacity(
      opacity: 1 - _window(t, 11.5, 0.4),
      child: Center(
        child: _MiniPhone(
          island: ringing,
          screen: Stack(
            children: [
              Positioned.fill(
                child: _IosLock(
                  children: [
                    Positioned(
                      top: 250,
                      left: 0,
                      right: 0,
                      child: _layer(
                        _window(t, 1, 0.35),
                        const _IosNotice(),
                        from: const Offset(0, -40),
                      ),
                    ),
                    Positioned(
                      top: 400,
                      left: 0,
                      right: 0,
                      child: _layer(
                        _window(t, 1.8, 0.35),
                        _LiveActivity(seconds: seconds),
                        from: const Offset(0, 30),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: _layer(
                  _shown(t, 3.3, 6.3),
                  _AlarmKitAlert(press: _press(t, 5.8)),
                  from: const Offset(0, 60),
                ),
              ),
              Positioned.fill(
                child: _layer(
                  _shown(t, 6.2, 8.8),
                  _AppAlarm(seconds: seconds, press: _press(t, 8.4)),
                ),
              ),
              Positioned.fill(
                child: _layer(
                  _shown(t, 8.7, 20),
                  const _AckScreen(seconds: 8),
                ),
              ),
              _finger(
                _systemImUp,
                _shown(t, 5.2, 6.1, fade: 0.2),
                _press(t, 5.8),
              ),
              _finger(
                _appImUp,
                _shown(t, 7.8, 8.7, fade: 0.2),
                _press(t, 8.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. On Android.

class _AndroidHero extends StatefulWidget {
  const _AndroidHero();

  @override
  State<_AndroidHero> createState() => _AndroidHeroState();
}

class _AndroidHeroState extends _ClockState<_AndroidHero> {
  @override
  double get restAt => 4;

  @override
  Widget build(BuildContext context) {
    final t = this.t % 10;
    final seconds = (t - 1).clamp(0, 99).floor() + 1;

    return Opacity(
      opacity: 1 - _window(t, 9.5, 0.4),
      child: Center(
        child: Transform.rotate(
          angle: math.sin(t * 50) * 0.012 * _shown(t, 1, 6.6, fade: 0.1),
          child: _MiniPhone(
            isAndroid: true,
            screen: Stack(
              children: [
                const Positioned.fill(child: _AndroidLock()),
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: _layer(
                    _shown(t, 1, 2.9),
                    const _AndroidNotice(),
                    from: const Offset(0, -120),
                  ),
                ),
                Positioned.fill(
                  child: _layer(
                    _shown(t, 2.6, 6.6),
                    _AppAlarm(seconds: seconds, press: _press(t, 6.1)),
                    from: const Offset(0, 80),
                  ),
                ),
                Positioned.fill(
                  child: _layer(
                    _shown(t, 6.5, 20),
                    const _AckScreen(seconds: 5),
                  ),
                ),
                _finger(
                  _appImUp,
                  _shown(t, 5.4, 6.4, fade: 0.2),
                  _press(t, 6.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. The priority ladder.

class _LadderHero extends StatefulWidget {
  const _LadderHero();

  @override
  State<_LadderHero> createState() => _LadderHeroState();
}

class _LadderHeroState extends _ClockState<_LadderHero> {
  @override
  double get restAt => 4;

  @override
  Widget build(BuildContext context) {
    final t = this.t % 10;
    final colors = context.appColors;
    final acked = t > 6.6;
    final ringing = t > 2.6 && !acked;

    Widget card({
      required int index,
      required String priority,
      required String topic,
      required String title,
      required FaceState face,
      required Widget outcome,
      Color? tint,
      double shake = 0,
    }) {
      final arrive = Curves.easeOutBack.transform(
        _window(t, 0.3 + index * 1.1, 0.6),
      );
      return Opacity(
        opacity: _window(t, 0.3 + index * 1.1, 0.3),
        child: Transform.translate(
          offset: Offset((1 - arrive) * 260 + shake, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tint ?? colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: AppTypography.monoBold(colors.ink, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                FaceWidget(
                  state: face,
                  size: 48,
                  isLive: face == FaceState.alarmed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic,
                        style: AppTypography.mono(colors.ink3, fontSize: 12),
                      ),
                      Text(
                        title,
                        style: AppTypography.title(colors.ink, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      outcome,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget chip(String label, IconData icon, Color fill, Color text) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    // The bell swings while the P3 notice lands.
    final swing = math.sin(t * 30) * 0.4 * _shown(t, 1.4, 2.3, fade: 0.1);

    return Opacity(
      opacity: 1 - _window(t, 9.4, 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            card(
              index: 0,
              priority: 'P2',
              topic: 'nightly-backup',
              title: LocaleKeys.onboarding_welcome_story_backup_done.tr(),
              face: FaceState.content,
              outcome: chip(
                LocaleKeys.onboarding_welcome_story_quiet.tr(),
                Icons.notifications_off_outlined,
                colors.cream,
                colors.ink3,
              ),
            ),
            const SizedBox(height: Spacing.s3),
            card(
              index: 1,
              priority: 'P3',
              topic: 'disk-space',
              title: LocaleKeys.onboarding_welcome_story_disk_warning.tr(),
              face: FaceState.concerned,
              outcome: Transform.rotate(
                angle: swing,
                alignment: Alignment.centerLeft,
                child: chip(
                  LocaleKeys.onboarding_welcome_story_notifies.tr(),
                  Icons.notifications_active_outlined,
                  colors.high,
                  _darkInk,
                ),
              ),
            ),
            const SizedBox(height: Spacing.s3),
            _RingWaves(
              t: t,
              color: colors.crit,
              isOn: ringing,
              child: card(
                index: 2,
                priority: 'P5',
                topic: 'prod-db',
                title: LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
                face: acked ? FaceState.acked : FaceState.alarmed,
                tint: acked
                    ? colors.cobaltTint
                    : (ringing ? colors.critTint : null),
                shake: ringing ? math.sin(t * 60) * 3 : 0,
                outcome: acked
                    ? chip(
                        LocaleKeys.onboarding_welcome_story_acknowledged.tr(),
                        Icons.check,
                        colors.cobalt,
                        _white,
                      )
                    : chip(
                        LocaleKeys.onboarding_welcome_story_rings.tr(),
                        Icons.alarm,
                        colors.crit,
                        _white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 10. Server to phone and back.

class _PipelineHero extends StatefulWidget {
  const _PipelineHero();

  @override
  State<_PipelineHero> createState() => _PipelineHeroState();
}

class _PipelineHeroState extends _ClockState<_PipelineHero> {
  @override
  double get restAt => 3.5;

  @override
  Widget build(BuildContext context) {
    final t = this.t % 10;
    final colors = context.appColors;

    final server = t < 0.4
        ? _shape(FaceState.calm)
        : t < 0.7
        ? _blend(FaceState.calm, FaceState.shocked, _window(t, 0.4, 0.3))
        : t < 1.3
        ? _shape(FaceState.shocked)
        : t < 7.3
        ? _blend(FaceState.shocked, FaceState.worried, _window(t, 1.3, 0.3))
        : _blend(FaceState.worried, FaceState.happy, _window(t, 7.3, 0.3));
    final relay = t < 1.5
        ? _shape(FaceState.calm)
        : t < 6.8
        ? _blend(FaceState.calm, FaceState.determined, _window(t, 1.5, 0.3))
        : _blend(FaceState.determined, FaceState.happy, _window(t, 6.8, 0.3));
    final ringing = t > 2.4 && t < 5.9;
    final phoneState = t < 2.4
        ? FaceState.calm
        : ringing
        ? FaceState.alarmed
        : t < 7.6
        ? FaceState.acked
        : FaceState.happy;
    final seconds = (t - 2.4).clamp(0, 99).floor() + 1;

    return Opacity(
      opacity: 1 - _window(t, 9.5, 0.4),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final y = box.maxHeight * 0.45;
          final xs = [w * 0.15, w * 0.5, w * 0.85];
          final face = math.min(84, w * 0.22).toDouble();

          Offset along(int from, int to, double p) =>
              Offset.lerp(Offset(xs[from], y), Offset(xs[to], y), p)!;

          final out1 = _window(t, 1, 0.6);
          final out2 = _window(t, 1.7, 0.6);
          final back = _window(t, 6, 1.3);

          Widget node(double x, Widget child, String caption) => Positioned(
            left: x - 60,
            width: 120,
            top: y - face / 2,
            child: Column(
              children: [
                child,
                const SizedBox(height: Spacing.s2),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: AppTypography.small(
                    colors.onCanvas,
                    fontSize: 13,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PipePainter(
                    y: y,
                    xs: xs,
                    color: colors.onCanvas,
                  ),
                ),
              ),
              node(
                xs[0],
                _face(server, face, fill: const Color(0xFF4EAAD8)),
                LocaleKeys.onboarding_welcome_story_your_server.tr(),
              ),
              node(
                xs[1],
                _face(relay, face),
                LocaleKeys.app_title.tr(),
              ),
              node(
                xs[2],
                SizedBox.square(
                  dimension: face,
                  child: _RingWaves(
                    t: t,
                    color: colors.crit,
                    isOn: ringing,
                    child: Transform.rotate(
                      angle: ringing ? math.sin(t * 50) * 0.08 : 0,
                      child: FaceWidget(
                        state: phoneState,
                        size: face,
                        overrideFillColor: const Color(0xFFF2A7C3),
                        overrideStrokeColor: _darkInk,
                        overrideInkColor: _darkInk,
                      ),
                    ),
                  ),
                ),
                ringing
                    ? _secs(
                        LocaleKeys.onboarding_welcome_story_ringing_for,
                        seconds,
                      )
                    : LocaleKeys.onboarding_welcome_story_your_phone.tr(),
              ),
              if (out1 > 0 && out1 < 1) _packet(along(0, 1, out1), colors.crit),
              if (out2 > 0 && out2 < 1) _packet(along(1, 2, out2), colors.crit),
              if (back > 0 && back < 1)
                _packet(along(2, 0, back), colors.cobalt, label: '✓'),
              Positioned(
                left: xs[2] - 36,
                top: y - 36,
                child: _layer(
                  _shown(t, 5.2, 6.1, fade: 0.2),
                  Transform.scale(
                    scale: 1 - 0.25 * _press(t, 5.8),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.onCanvas.withValues(alpha: 0.18),
                        border: Border.all(color: colors.onCanvas, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _packet(Offset at, Color color, {String? label}) => Positioned(
    left: at.dx - 14,
    top: at.dy - 14 - 64,
    child: Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
        ],
      ),
      child: Text(
        label ?? 'P5',
        style: const TextStyle(
          color: _white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// The dashed track the messages run along, above the faces.
class _PipePainter extends CustomPainter {
  _PipePainter({required this.y, required this.xs, required this.color});

  final double y;
  final List<double> xs;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    final lineY = y - 64;
    for (var x = xs.first; x < xs.last; x += 12) {
      canvas.drawLine(
        Offset(x, lineY),
        Offset(math.min(x + 6, xs.last), lineY),
        paint,
      );
    }
    for (final x in xs) {
      canvas.drawCircle(Offset(x, lineY), 4, paint);
    }
  }

  @override
  bool shouldRepaint(_PipePainter old) => old.y != y || old.color != color;
}

// ---------------------------------------------------------------------------
// 11. Home screen widgets. Drawn after the real ones in the home-widgets
// branch: a count, a ringing card with I'm up, and the topic list.

class _WidgetsHero extends StatefulWidget {
  const _WidgetsHero();

  @override
  State<_WidgetsHero> createState() => _WidgetsHeroState();
}

class _WidgetsHeroState extends _ClockState<_WidgetsHero> {
  @override
  double get restAt => 2.5;

  static const Color _cream = Color(0xFFF7F1EA);
  static const Color _muted = Color(0xFF7A7068);
  static const Color _quietFill = Color(0xFFE6DDD2);

  @override
  Widget build(BuildContext context) {
    final t = this.t % 10;
    final colors = context.appColors;

    // prod rings, then someone taps I'm up (awake), then Done (quiet).
    final prodAwake = t > 4.3;
    final prodQuiet = t > 7.2;
    final open = prodQuiet ? 3 : 4;
    final countUp = (_window(t, 0.6, 0.8) * open).round();

    Widget tile(FaceState state, Color fill, double size) => FaceWidget(
      state: state,
      size: size,
      isLive: state == FaceState.alarmed,
      overrideFillColor: fill,
      overrideStrokeColor: _darkInk,
      overrideInkColor: _darkInk,
    );

    Widget ringingBadge() =>
        _badge(LocaleKeys.onboarding_welcome_story_ringing.tr(), colors.crit);
    Widget awakeBadge() =>
        _badge(LocaleKeys.onboarding_welcome_story_awake.tr(), colors.cobalt);
    Widget quietBadge() => _badge(
      LocaleKeys.onboarding_welcome_story_quiet_badge.tr(),
      _quietFill,
      text: _muted,
    );

    Widget card(Widget child, {required double w, double? h}) => Container(
      width: w,
      height: h,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    /// Pops in at [at] and floats, tipped a little like it sits on a table.
    Widget float(Widget child, double at, double tip) {
      final pop = Curves.easeOutBack.transform(_window(t, at, 0.6));
      final bob = math.sin((t + at) * 1.8) * 3;
      final scale = 0.8 + 0.2 * pop;
      return Opacity(
        opacity: _window(t, at, 0.25),
        child: Transform.translate(
          offset: Offset(0, bob + (1 - pop) * 30),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(0.08)
              ..rotateY(tip),
            child: Transform.scale(scale: scale, child: child),
          ),
        ),
      );
    }

    final count = card(
      w: 160,
      h: 176,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              tile(FaceState.alarmed, colors.crit, 40),
              const Spacer(),
              ringingBadge(),
            ],
          ),
          const Spacer(),
          Text(
            '$countUp',
            style: AppTypography.display(_darkInk, fontSize: 48),
          ),
          Text(
            '${LocaleKeys.onboarding_welcome_story_open_label.tr()} · prod',
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final ringingCard = card(
      w: 160,
      h: 176,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (prodQuiet)
                tile(FaceState.calm, _yellow, 40)
              else if (prodAwake)
                tile(FaceState.acked, colors.cobalt, 40)
              else
                tile(FaceState.alarmed, colors.crit, 40),
              const Spacer(),
              if (prodQuiet)
                quietBadge()
              else if (prodAwake)
                awakeBadge()
              else
                ringingBadge(),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Text(
                'prod',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text('8:47:41', style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
          Text(
            LocaleKeys.onboarding_welcome_story_db_primary_down.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _darkInk,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const Spacer(),
          if (!prodQuiet)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: prodAwake ? colors.cobalt : colors.crit,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                prodAwake
                    ? LocaleKeys.onboarding_welcome_story_done.tr()
                    : LocaleKeys.onboarding_welcome_story_im_up.tr(),
                style: const TextStyle(
                  color: _white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );

    Widget row(
      String topic,
      String message,
      String time,
      Widget face,
      Widget badge,
    ) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          face,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      topic,
                      style: const TextStyle(
                        color: _darkInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    badge,
                  ],
                ),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );

    final list = card(
      w: 336,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                LocaleKeys.onboarding_welcome_story_open_count.tr(
                  namedArgs: {'count': '$open'},
                ),
                style: const TextStyle(
                  color: _darkInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                LocaleKeys.onboarding_welcome_story_more.tr(
                  namedArgs: {'count': '2'},
                ),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          row(
            'prod',
            LocaleKeys.onboarding_welcome_story_db_primary_down.tr(),
            '8:47:07',
            prodQuiet
                ? tile(FaceState.calm, _yellow, 30)
                : prodAwake
                ? tile(FaceState.acked, colors.cobalt, 30)
                : tile(FaceState.alarmed, colors.crit, 30),
            prodQuiet
                ? quietBadge()
                : prodAwake
                ? awakeBadge()
                : ringingBadge(),
          ),
          row(
            'queue',
            LocaleKeys.onboarding_welcome_story_queue_backed_up.tr(),
            '8:41:37',
            tile(FaceState.alarmed, colors.crit, 30),
            ringingBadge(),
          ),
          row(
            'backups',
            LocaleKeys.onboarding_welcome_story_backup_exited.tr(),
            '9:45:07',
            tile(FaceState.acked, colors.cobalt, 30),
            awakeBadge(),
          ),
        ],
      ),
    );

    // Where the ringing card's button sits, for the finger.
    const tap = Offset(176 + 14 + 38, 176 - 14 - 16);

    return Opacity(
      opacity: 1 - _window(t, 9.5, 0.4),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 336,
            height: 176 + 18 + 250,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: 0, top: 0, child: float(count, 0, 0.12)),
                Positioned(
                  left: 176,
                  top: 0,
                  child: float(ringingCard, 0.25, -0.12),
                ),
                Positioned(left: 0, top: 194, child: float(list, 0.5, 0)),
                Positioned(
                  left: tap.dx - 26,
                  top: tap.dy - 26,
                  child: _layer(
                    math.max(
                      _shown(t, 3.6, 4.5, fade: 0.2),
                      _shown(t, 6.5, 7.4, fade: 0.2),
                    ),
                    Transform.scale(
                      scale:
                          1 - 0.25 * math.max(_press(t, 4.2), _press(t, 7.1)),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.onCanvas.withValues(alpha: 0.2),
                          border: Border.all(color: colors.onCanvas, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
