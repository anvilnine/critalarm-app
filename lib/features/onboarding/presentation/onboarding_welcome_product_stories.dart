part of 'onboarding_welcome_screen.dart';

// The three stories the welcome screen plays on first launch. Each one shows
// one thing the app does, drawn with the same phone, cards and colours as
// the How it rings story. The second one is the priority ladder, which lives
// with the older stories in onboarding_welcome_stories.dart.

/// The stories of the welcome screen, in the order they play.
enum _WelcomeStory {
  /// A phone at night. An alert lands, and the alarm rings until it is
  /// stopped.
  rings,

  /// Three alerts of rising priority: quiet, a notification, a ring.
  priorities,

  /// A monitor, a cron job and a script each send an alert to the phone.
  tools;

  /// The story that plays after this one. The last hands back to the first.
  _WelcomeStory get next => values[(index + 1) % values.length];
}

/// The picture for [story], with one label for a screen reader. [onDone] is
/// called once, when the story is over.
Widget _welcomeStoryHero(
  _WelcomeStory story, {
  required bool ringsOnSilent,
  required VoidCallback onDone,
}) {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  return switch (story) {
    _WelcomeStory.rings => _RingStoryHero(
      isAndroid: isAndroid,
      isOnSilent: ringsOnSilent,
      onDone: onDone,
    ),
    _WelcomeStory.priorities => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_story_priorities_label.tr(),
      child: _LadderHero(onDone: onDone),
    ),
    _WelcomeStory.tools => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_story_tools_label.tr(),
      child: _ToolsStoryHero(isAndroid: isAndroid, onDone: onDone),
    ),
  };
}

/// A drawing a screen reader meets as one picture with one [label].
class _SpokenPicture extends StatelessWidget {
  const _SpokenPicture({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label: label,
    child: ExcludeSemantics(child: child),
  );
}

/// The line under the welcome title, one per story. It fades from one to the
/// next with the pictures and always keeps the height of the longest line,
/// so the title and the button never move.
class _StoryCaption extends StatelessWidget {
  const _StoryCaption({required this.story, required this.ringsOnSilent});

  final _WelcomeStory story;

  /// Whether this phone rings through silent mode. Only then does the first
  /// line say so.
  final bool ringsOnSilent;

  static String _lineFor(_WelcomeStory story, {required bool ringsOnSilent}) =>
      switch (story) {
        _WelcomeStory.rings =>
          ringsOnSilent
              ? LocaleKeys.onboarding_welcome_caption_rings_silent.tr()
              : LocaleKeys.onboarding_welcome_caption_rings.tr(),
        _WelcomeStory.priorities =>
          LocaleKeys.onboarding_welcome_caption_priorities.tr(),
        _WelcomeStory.tools => LocaleKeys.onboarding_welcome_caption_tools.tr(),
      };

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.lead(
      context.appColors.onCanvasMuted,
      fontSize: 16,
    );
    final everyLine = [
      for (final each in _WelcomeStory.values)
        for (final onSilent in [true, false])
          _lineFor(each, ringsOnSilent: onSilent),
    ];
    return Stack(
      children: [
        // Every line, unseen, so the room is that of the tallest one.
        for (final line in everyLine.toSet())
          ExcludeSemantics(
            child: Opacity(opacity: 0, child: Text(line, style: style)),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 450)),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              _lineFor(story, ringsOnSilent: ringsOnSilent),
              // Keyed by the story, so the words about silent mode arriving
              // a moment after launch do not fade.
              key: ValueKey(story),
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Story 1. It rings until you answer.

/// A phone at night. An alert lands on the lock screen, the alarm takes the
/// screen and rings, and it stops when "I'm up" is tapped: by the user, in
/// the picture, or by itself a few seconds later.
class _RingStoryHero extends StatefulWidget {
  const _RingStoryHero({
    required this.isAndroid,
    required this.isOnSilent,
    required this.onDone,
  });

  final bool isAndroid;

  /// Draws the phone in silent mode. Only for a phone that does ring
  /// through it.
  final bool isOnSilent;

  /// Called once, when the story is over.
  final VoidCallback onDone;

  @override
  State<_RingStoryHero> createState() => _RingStoryHeroState();
}

class _RingStoryHeroState extends _ClockState<_RingStoryHero> {
  /// A still hero rests on the ringing alarm, with its stop button in reach.
  @override
  double get restAt => 3;

  /// When the user tapped the stop button, on the hero's clock.
  double? _tappedAt;
  bool _hasSaidDone = false;

  @override
  List<TimedCue> buildCues() => ringStoryCues();

  /// No pulse plays once the ring was stopped.
  @override
  bool mayPlay(HeroCue cue) =>
      cue != HeroCue.ringPulse ||
      ringStoryIsRinging(_seconds, tappedAt: _tappedAt);

  @override
  void onClock(double seconds) {
    if (_hasSaidDone || seconds < ringStoryEndsAt(tappedAt: _tappedAt)) return;
    _hasSaidDone = true;
    widget.onDone();
  }

  /// The user tapped "I'm up" in the picture. The ring stops on this frame
  /// and the press is felt here, so the tap is answered at once.
  void _stop() {
    final at = t;
    if (!ringStoryIsRinging(at, tappedAt: _tappedAt)) return;
    setState(() => _tappedAt = at);
    AppHaptics.capture();
  }

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final isAndroid = widget.isAndroid;
    final stopsAt = ringStoryStopsAt(tappedAt: _tappedAt);
    final isRinging = ringStoryIsRinging(t, tappedAt: _tappedAt);
    final hasStopped = t >= stopsAt;

    // The shake comes on fast and is gone on the frame the ring stops.
    final ring = isRinging ? _window(t, ringStoryRingStartsAt, 0.15) : 0.0;
    final takeOver = _window(
      t,
      ringStoryRingStartsAt,
      ringStoryTakeOverTakes,
    );
    final acked = !hasStopped
        ? 0.0
        : _isStill
        ? 1.0
        : _window(t, stopsAt, 0.2);
    final rangFor = (stopsAt - ringStoryRingStartsAt).floor() + 1;
    final seconds = hasStopped
        ? rangFor
        : (t - ringStoryRingStartsAt).clamp(0, 99).floor() + 1;

    // With no tap from the user a finger in the picture presses the button.
    const pressAt = ringStoryAutoStopAt - 0.1;
    final showsFinger = _tappedAt == null && !_isStill;
    final finger = showsFinger
        ? _shown(t, pressAt - 0.7, pressAt + 0.15, fade: 0.2)
        : 0.0;
    final press = showsFinger ? _press(t, pressAt) : 0.0;

    final phone = Transform.rotate(
      angle: math.sin(t * phoneShakeRate) * 0.012 * ring,
      child: _MiniPhone(
        isAndroid: isAndroid,
        isSilent: widget.isOnSilent,
        island: isRinging ? _window(t, ringStoryRingStartsAt, 0.25) : 0,
        screen: Stack(
          children: [
            Positioned.fill(
              child: isAndroid ? const _AndroidLock() : const _IosLock(),
            ),
            if (widget.isOnSilent)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: Center(child: _SilentPill()),
              ),
            Positioned(
              top: isAndroid ? 60 : 250,
              left: 0,
              right: 0,
              child: _layer(
                _window(t, ringStoryAlertStartsAt, ringStoryAlertTakes),
                isAndroid ? const _AndroidNotice() : const _IosNotice(),
                from: Offset(0, isAndroid ? -120 : -40),
              ),
            ),
            if (acked < 1)
              Positioned.fill(
                child: _layer(
                  takeOver,
                  _AppAlarm(seconds: seconds, press: press),
                  from: const Offset(0, 60),
                ),
              ),
            Positioned.fill(
              child: _layer(acked, _AckScreen(seconds: rangFor)),
            ),
            _finger(_appImUp, finger, press),
          ],
        ),
      ),
    );

    final String label;
    if (hasStopped) {
      label = LocaleKeys.onboarding_welcome_story_rings_label_stopped.tr();
    } else if (widget.isOnSilent) {
      label = LocaleKeys.onboarding_welcome_story_rings_label_silent.tr();
    } else {
      label = LocaleKeys.onboarding_welcome_story_rings_label.tr();
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Where the phone and its "I'm up" button come out in this room, so
        // the tap area can be a full finger tall however small the phone is
        // drawn.
        const fullW = _MiniPhone._w + 2 * _MiniPhone._bezel;
        const fullH = _MiniPhone._h + 2 * _MiniPhone._bezel;
        final scale = math.min(
          box.maxHeight / fullH,
          box.maxWidth / fullW,
        );
        final phoneW = fullW * scale;
        final phoneTop = (box.maxHeight - fullH * scale) / 2;
        final buttonY = phoneTop + (_MiniPhone._bezel + _appImUp.dy) * scale;
        final tapHeight = math.max(setupMinTapHeight + 4, 64 * scale + 24);

        return Semantics(
          container: true,
          image: true,
          label: label,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(child: Center(child: phone)),
              ),
              if (isRinging && takeOver >= 1)
                Positioned(
                  left: (box.maxWidth - phoneW) / 2,
                  width: phoneW,
                  top: buttonY - tapHeight / 2,
                  height: tapHeight,
                  child: Semantics(
                    button: true,
                    label: LocaleKeys.onboarding_welcome_story_rings_stop.tr(),
                    onTap: _stop,
                    child: Listener(
                      // On the way down: waiting for the finger to lift would
                      // make the alarm feel slow to stop.
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _stop(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The lock screen's own sign that the phone is in silent mode.
class _SilentPill extends StatelessWidget {
  const _SilentPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0x33FFFFFF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.notifications_off, color: _white, size: 24),
        const SizedBox(width: 8),
        Text(
          LocaleKeys.onboarding_welcome_story_silent.tr(),
          style: const TextStyle(
            color: _white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Story 3. Works with what you run.

/// Three of the user's own tools on the left, their phone on the right. Each
/// tool sends one alert along its own line, and it lands on the lock screen.
class _ToolsStoryHero extends StatefulWidget {
  const _ToolsStoryHero({required this.isAndroid, required this.onDone});

  final bool isAndroid;

  /// Called once, when the story is over.
  final VoidCallback onDone;

  @override
  State<_ToolsStoryHero> createState() => _ToolsStoryHeroState();
}

class _ToolsStoryHeroState extends _ClockState<_ToolsStoryHero> {
  /// A still hero rests with all three alerts on the phone.
  @override
  double get restAt => 5;

  bool _hasSaidDone = false;

  @override
  List<TimedCue> buildCues() => toolsStoryCues();

  @override
  void onClock(double seconds) {
    if (_hasSaidDone || seconds < toolsStoryTakes) return;
    _hasSaidDone = true;
    widget.onDone();
  }

  /// The least height the drawing is laid out at. In less room it is scaled
  /// down whole.
  static const double _minHeight = 250;
  static const double _toolHeight = 60;
  static const double _toolGap = 14;

  /// The room between the tools and the phone, where the lines run.
  static const double _lineRoom = 44;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final colors = context.appColors;
    final isAndroid = widget.isAndroid;

    final tools = <(IconData, String, String)>[
      (
        Icons.monitor_heart_outlined,
        LocaleKeys.onboarding_welcome_story_tool_monitor.tr(),
        'GET /health  503',
      ),
      (
        Icons.schedule,
        LocaleKeys.onboarding_welcome_story_tool_cron.tr(),
        '0 3 * * *  backup.sh',
      ),
      (
        Icons.terminal,
        LocaleKeys.onboarding_welcome_story_tool_script.tr(),
        './deploy.sh  exit 1',
      ),
    ];
    final alerts = <(String, String)>[
      ('prod-db', LocaleKeys.onboarding_welcome_story_alarm_title.tr()),
      ('backups', LocaleKeys.onboarding_welcome_story_backup_exited.tr()),
      ('deploys', LocaleKeys.onboarding_welcome_story_deploy_failed.tr()),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = math.max(box.maxHeight, _minHeight);
        const phoneShape =
            (_MiniPhone._h + 2 * _MiniPhone._bezel) /
            (_MiniPhone._w + 2 * _MiniPhone._bezel);
        final phoneH = math.min(h, w * 0.4 * phoneShape);
        final phoneW = phoneH / phoneShape;
        final phoneLeft = w - phoneW;
        final toolW = phoneLeft - _lineRoom;
        final toolsTop =
            (h - toolsStoryToolCount * _toolHeight - 2 * _toolGap) / 2;

        double toolTop(int index) =>
            toolsTop + index * (_toolHeight + _toolGap);
        // Each line leaves the middle of its tool and reaches the side of
        // the phone a little apart from the others.
        final starts = [
          for (var i = 0; i < toolsStoryToolCount; i++)
            Offset(toolW, toolTop(i) + _toolHeight / 2),
        ];
        final ends = [
          for (var i = 0; i < toolsStoryToolCount; i++)
            Offset(phoneLeft, h / 2 + (i - 1) * 26),
        ];

        // The one alert in flight, if any.
        int? sender;
        var sent = 0.0;
        for (var i = 0; i < toolsStoryToolCount; i++) {
          final p = _window(t, toolsSendStartsAt(i), toolsSendTakes);
          if (p > 0 && p < 1) {
            sender = i;
            sent = Curves.easeInOut.transform(p);
          }
        }

        Widget tool(int index) {
          final (icon, name, line) = tools[index];
          return Positioned(
            left: 0,
            top: toolTop(index),
            width: toolW,
            height: _toolHeight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sender == index ? colors.ink : colors.hairline,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: colors.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title(colors.ink, fontSize: 15),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            line,
                            style: AppTypography.mono(
                              colors.ink3,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget alert(int index) {
          final (topic, title) = alerts[index];
          return Positioned(
            top: (isAndroid ? 462 : 236) + index * 84,
            left: 0,
            right: 0,
            child: _layer(
              _window(t, toolsAlertLandsAt(index) - 0.05, 0.3),
              _ToolNotice(topic: topic, title: title),
              from: const Offset(-40, 0),
            ),
          );
        }

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Opacity(
              opacity: _window(t, 0, 0.25),
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ToolLinesPainter(
                          starts: starts,
                          ends: ends,
                          color: colors.onCanvas,
                          sender: sender,
                          sent: sent,
                        ),
                      ),
                    ),
                    for (var i = 0; i < toolsStoryToolCount; i++) tool(i),
                    Positioned(
                      left: phoneLeft,
                      top: (h - phoneH) / 2,
                      width: phoneW,
                      height: phoneH,
                      child: _MiniPhone(
                        isAndroid: isAndroid,
                        screen: Stack(
                          children: [
                            Positioned.fill(
                              child: isAndroid
                                  ? const _AndroidLock()
                                  : const _IosLock(),
                            ),
                            for (var i = 0; i < toolsStoryToolCount; i++)
                              alert(i),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One alert on the lock screen of the tools story: the topic it came in on
/// and what it says.
class _ToolNotice extends StatelessWidget {
  const _ToolNotice({required this.topic, required this.title});

  final String topic;
  final String title;

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF6E6E73);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE6E9E9EE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _appIcon(46, context.appColors.crit),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      LocaleKeys.onboarding_welcome_story_now.tr(),
                      style: const TextStyle(color: grey, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _darkInk, fontSize: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed lines from each tool to the phone, and the one alert that
/// travels along the line of [sender].
class _ToolLinesPainter extends CustomPainter {
  _ToolLinesPainter({
    required this.starts,
    required this.ends,
    required this.color,
    required this.sender,
    required this.sent,
  });

  final List<Offset> starts;
  final List<Offset> ends;
  final Color color;

  /// The tool whose alert is in flight, or null when none is.
  final int? sender;

  /// How far along its line that alert is, from 0 to 1.
  final double sent;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.25);
    for (var i = 0; i < starts.length; i++) {
      final a = starts[i];
      final b = ends[i];
      final bend = (b.dx - a.dx) * 0.55;
      final line = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + bend, a.dy, b.dx - bend, b.dy, b.dx, b.dy);
      for (final metric in line.computeMetrics()) {
        // Dashed like the track of the older server story: 6 on, 6 off.
        for (var at = 0.0; at < metric.length; at += 12) {
          canvas.drawPath(
            metric.extractPath(at, math.min(at + 6, metric.length)),
            track,
          );
        }
        if (i == sender) {
          final where = metric.getTangentForOffset(metric.length * sent);
          if (where != null) {
            canvas.drawCircle(where.position, 6, Paint()..color = color);
          }
        }
      }
      canvas.drawCircle(a, 4, track..style = PaintingStyle.fill);
      track.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(_ToolLinesPainter old) =>
      old.sender != sender ||
      old.sent != sent ||
      old.color != color ||
      !listEquals(old.starts, starts) ||
      !listEquals(old.ends, ends);
}
