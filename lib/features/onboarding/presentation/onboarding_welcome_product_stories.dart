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
  _HeroDrawn? wordHeroDrawn,
  ValueListenable<double>? wordSlide,
}) {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  return switch (page) {
    WelcomePage.rings => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_title.tr(),
      child: _WordStoryHero(
        onDone: onDone,
        drawn: wordHeroDrawn,
        slide: wordSlide,
      ),
    ),
    WelcomePage.curl => _SpokenPicture(
      label: LocaleKeys.onboarding_welcome_story_curl_label.tr(),
      child: isAndroid ? const _AndroidCurlHero() : const _CurlHero(),
    ),
    // A mock-up: the title and the line under it say what it shows.
    WelcomePage.widgets => const ExcludeSemantics(child: _WidgetsHero()),
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
