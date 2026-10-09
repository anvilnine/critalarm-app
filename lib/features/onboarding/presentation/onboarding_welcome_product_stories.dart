part of 'onboarding_welcome_screen.dart';

// The pages of the welcome screen on first launch. Each one shows one thing
// the app does, drawn with the same phone, cards and colours. The second one
// is the curl that rings a phone and the third is the home screen widgets,
// which both live with the older stories in onboarding_welcome_stories.dart.

/// The picture for [page], with one label for a screen reader. [onDone] is
/// called once, when a story that ends is over. The curl plays round and
/// round and never calls it.
Widget _welcomeStoryHero(
  WelcomePage page, {
  required bool ringsOnSilent,
  required VoidCallback onDone,
  WelcomeFirstPage firstPage = welcomeFirstPage,
  _HeroDrawn? wordHeroDrawn,
  ValueListenable<double>? wordSlide,
}) {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  return switch (page) {
    WelcomePage.rings => switch (firstPage) {
      WelcomeFirstPage.word => _SpokenPicture(
        label: LocaleKeys.onboarding_welcome_title.tr(),
        child: _WordStoryHero(
          onDone: onDone,
          drawn: wordHeroDrawn,
          slide: wordSlide,
        ),
      ),
      // Draws its own title, like the word page.
      WelcomeFirstPage.nightFalls => _SpokenPicture(
        label: LocaleKeys.onboarding_welcome_title.tr(),
        child: _NightFallsHero(
          onDone: onDone,
          drawn: wordHeroDrawn,
          slide: wordSlide,
        ),
      ),
      // No title of its own: the shared title stays under the picture.
      WelcomeFirstPage.staysSilent => _SpokenPicture(
        label: LocaleKeys.welcome_first_pages_stays_silent_label.tr(),
        child: _StaysSilentHero(onDone: onDone, slide: wordSlide),
      ),
    },
    WelcomePage.curl => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_story_curl_label.tr(),
      child: isAndroid ? const _AndroidCurlHero() : const _CurlHero(),
    ),
    // A mock-up: the title and the line under it say what it shows.
    WelcomePage.widgets => const ExcludeSemantics(child: _WidgetsHero()),
  };
}

/// Fades a part of a first page and shifts it sideways by the slide of the
/// pager, so the page never shows it cut by an edge. [partingAt] says how
/// much of it shows and how many page widths it shifts, for a slide from 0
/// to 1. Draws the part as it is when the page has no slide.
class _PartingLayer extends StatelessWidget {
  const _PartingLayer({
    required this.slide,
    required this.pageWidth,
    required this.partingAt,
    required this.child,
  });

  final ValueListenable<double>? slide;
  final double pageWidth;
  final ({double opacity, double shift}) Function(double slide) partingAt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slide = this.slide;
    if (slide == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: slide,
      child: child,
      builder: (context, value, child) {
        final parting = partingAt(value);
        if (parting.opacity <= 0) return const SizedBox.shrink();
        return Opacity(
          opacity: parting.opacity,
          child: Transform.translate(
            offset: Offset(parting.shift * pageWidth, 0),
            child: child,
          ),
        );
      },
    );
  }
}

/// The parting of a night sky or panel behind a first page.
({double opacity, double shift}) _backdropParting(double slide) {
  final parting = welcomeBackdropPartingAt(slide);
  return (opacity: parting.opacity, shift: parting.shift);
}

/// The parting of the title of a first page that draws one.
({double opacity, double shift}) _titleParting(double slide) {
  final parting = welcomeWordPartingAt(slide);
  return (opacity: parting.titleOpacity, shift: parting.titleShift);
}

/// The parting of the face of a first page.
({double opacity, double shift}) _faceParting(double slide) {
  final parting = welcomeWordPartingAt(slide);
  return (opacity: parting.faceOpacity, shift: parting.faceShift);
}

/// The colours of a night scene on a first page, all from the panel tokens,
/// so a night looks the same in the light and the dark theme.
class _NightColors {
  factory _NightColors(AppColors colors) {
    final sky = Color.lerp(colors.panel, colors.cobaltOnDark, 0.10)!;
    Color toward(Color color, double amount) => Color.lerp(sky, color, amount)!;
    return _NightColors._(
      sky: sky,
      text: colors.onPanel,
      star: Color.lerp(colors.onPanel, colors.cobaltOnDark, 0.25)!,
      dimInk: toward(
        Color.lerp(colors.onPanelMuted, colors.cobaltOnDark, 0.5)!,
        0.8,
      ),
      dimFill: toward(colors.cobaltOnDark, 0.20),
      rowFill: toward(colors.cobaltOnDark, 0.12),
      rowBar: toward(colors.cobaltOnDark, 0.26),
    );
  }

  const _NightColors._({
    required this.sky,
    required this.text,
    required this.star,
    required this.dimInk,
    required this.dimFill,
    required this.rowFill,
    required this.rowBar,
  });

  /// The night sky.
  final Color sky;

  /// Text and lines on the sky.
  final Color text;

  /// A star.
  final Color star;

  /// A face asleep and the muted text: dim lines on the sky.
  final Color dimInk;

  /// The head of a face asleep.
  final Color dimFill;

  /// A muted notification and the bar inside it.
  final Color rowFill;
  final Color rowBar;
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
        WelcomePage.curl => LocaleKeys.onboarding_welcome_caption_curl.tr(),
        WelcomePage.widgets =>
          LocaleKeys.onboarding_welcome_widgets_subtitle.tr(),
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
