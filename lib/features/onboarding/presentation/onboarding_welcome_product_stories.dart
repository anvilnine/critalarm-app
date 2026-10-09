part of 'onboarding_welcome_screen.dart';

// The pages of the welcome screen on first launch. Each one shows one thing
// the app does, drawn with the same phone, cards and colours. The second one
// is the priority ladder and the third is the curl that rings a phone, which
// both live with the older stories in onboarding_welcome_stories.dart.

/// The picture for [page], with one label for a screen reader. [onDone] is
/// called once, when a story that ends is over. The curl plays round and
/// round and never calls it.
Widget _welcomeStoryHero(
  WelcomePage page, {
  required bool ringsOnSilent,
  required VoidCallback onDone,
  _HeroDrawn? wordHeroDrawn,
}) {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  return switch (page) {
    WelcomePage.rings => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_title.tr(),
      child: _WordStoryHero(onDone: onDone, drawn: wordHeroDrawn),
    ),
    WelcomePage.priorities => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_story_priorities_label.tr(),
      child: _LadderHero(onDone: onDone),
    ),
    WelcomePage.curl => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_story_curl_label.tr(),
      child: isAndroid ? const _AndroidCurlHero() : const _CurlHero(),
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

/// The line under the welcome title, one per page. It fades from one to the
/// next as the page changes and always keeps the height of the longest line,
/// so the title and the button never move.
class _StoryCaption extends StatelessWidget {
  const _StoryCaption({required this.page, required this.ringsOnSilent});

  final WelcomePage page;

  /// Whether this phone rings through silent mode. Only then does the first
  /// line say so.
  final bool ringsOnSilent;

  static String _lineFor(WelcomePage page, {required bool ringsOnSilent}) =>
      switch (page) {
        WelcomePage.rings =>
          ringsOnSilent
              ? LocaleKeys.onboarding_welcome_caption_rings_silent.tr()
              : LocaleKeys.onboarding_welcome_caption_rings.tr(),
        WelcomePage.priorities =>
          LocaleKeys.onboarding_welcome_caption_priorities.tr(),
        WelcomePage.curl => LocaleKeys.onboarding_welcome_caption_curl.tr(),
      };

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.lead(
      context.appColors.onCanvasMuted,
      fontSize: 16,
    );
    final everyLine = [
      for (final each in WelcomePage.values)
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
              _lineFor(page, ringsOnSilent: ringsOnSilent),
              // Keyed by the page, so the words about silent mode arriving
              // a moment after launch do not fade.
              key: ValueKey(page),
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
