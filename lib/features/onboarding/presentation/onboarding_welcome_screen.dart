import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/hero_haptic_cues.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/domain/welcome_pages.dart';
import 'package:critalarm/features/onboarding/domain/welcome_timing.dart';
import 'package:critalarm/features/onboarding/domain/welcome_word_timeline.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/curl_terminal.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/pages_above.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_step_dots.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

part 'onboarding_intro_steps.dart';
part 'onboarding_welcome_product_stories.dart';
part 'onboarding_welcome_stories.dart';
part 'onboarding_welcome_variants.dart';
part 'onboarding_welcome_word_story.dart';

/// The older welcome animations, kept for the Developer options preview and
/// for the steps that still use one. The first five are only faces, the next
/// seven show how Crit Alarm works, and the last three are faces again. First
/// launch shows the three welcome pages instead.
enum WelcomeVariant {
  /// One big face asleep, wakes up, smiles.
  wakeUp,

  /// A row of coloured faces slides in and does a wave.
  parade,

  /// Small faces circle a big one.
  orbit,

  /// A grid of every face in every colour, flipping over in waves.
  ripple,

  /// A face peeks over a ledge, looks around, then pops up.
  peekaboo,

  /// A curl in a terminal makes a phone ring.
  curl,

  /// An iPhone: notification, Live Activity, the system alarm, the app.
  iphone,

  /// An Android phone: heads-up notice, then the full screen alarm.
  android,

  /// Three messages at three priorities, and what each one does.
  ladder,

  /// Server to Crit Alarm to phone, and the acknowledgement back.
  pipeline,

  /// The home screen widgets: a count, a ringing card, the topic list.
  widgets,

  /// A curl in a terminal makes an Android phone ring.
  androidCurl,

  /// A face with what Crit Alarm does going round it.
  featureOrbit,

  /// The parade, but furious: they drop in, stomp and fume.
  angryParade,

  /// Ringing faces circling a big ringing face.
  ringingOrbit;

  /// `?v=1` to `?v=15`. Anything else is the first one.
  static WelcomeVariant fromQuery(String? value) {
    final index = (int.tryParse(value ?? '') ?? 1) - 1;
    return index >= 0 && index < values.length ? values[index] : wakeUp;
  }
}

/// Onboarding welcome screen (/onboarding/welcome), the first thing a new
/// user sees. With no [variant] it is three pages, each a picture with its
/// own caption: the ring story, the curl and the widgets. The user
/// swipes between them or taps Next, and the button on the last page starts
/// setup. Until the user moves by hand, each story hands on to the next page
/// when it ends. It always starts on the first one. Developer options opens
/// it with a [variant] and [isPreview] to try each of the older animations.
class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({
    this.variant,
    this.isPreview = false,
    super.key,
  });

  final WelcomeVariant? variant;

  /// Opened from Developer options: shows a switch for every animation, and
  /// Get started goes back instead of starting onboarding.
  final bool isPreview;

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  late WelcomeVariant _variant = widget.variant ?? WelcomeVariant.wakeUp;

  /// Bumped on every tap of the preview switch, so picking the one already
  /// showing plays it again from the start.
  int _replays = 0;

  bool get _isPlaylist => widget.variant == null && !widget.isPreview;

  /// Moves the pictures between the pages.
  PageController _pages = PageController();

  /// The page the dots, the caption and the button show. First launch
  /// always starts on the first one. During a swipe it changes half way.
  WelcomePage _page = WelcomePage.rings;

  /// The page the pictures last came to rest on.
  WelcomePage _restingOn = WelcomePage.rings;

  /// True from the moment the pictures start to move until they rest again.
  bool _isMoving = false;

  /// True from the user's first swipe or first tap on Next. From then on no
  /// page moves on by itself.
  bool _userHasMoved = false;

  /// Bumped every time a story starts over on its own page, so each pass
  /// plays from its start.
  int _passes = 0;

  /// A swipe in progress that started outside the pictures.
  Drag? _drag;

  /// How far a swipe has gone, while the pictures do not follow the finger.
  double _swiped = 0;

  /// What this phone can promise about ringing. Null until it has been
  /// read, and until then nothing says the phone rings on silent.
  RingClaim? _ringClaim;

  /// True while the phone asks for reduced motion.
  bool _isStill = false;

  /// Whether the first page is drawing its own title. It reports through
  /// this, so the small shared title hides only while it is.
  final _HeroDrawn _wordHeroDrawn = _HeroDrawn();

  /// How far the first page has moved off the screen, from 0 to 1. The big
  /// title, the face and the rings of that page leave by it, so a swipe
  /// never cuts through them.
  final ValueNotifier<double> _wordSlide = ValueNotifier(0);

  /// Where the canvas behind the screen is told the pager is, so the shapes
  /// glide with a swipe. Null outside the shell.
  AmbientPagePosition? _ambientPosition;

  List<ModalRoute<Object?>> _pagesAbove = const [];

  /// Whether the pictures follow the finger. They do not with animations
  /// switched off, or at a text size so large that the pictures are gone.
  bool get _followsFinger => !_isStill && _pages.hasClients;

  @override
  void initState() {
    super.initState();
    if (_isPlaylist) unawaited(_readRingClaim());
    _pages.addListener(_onPagesMoved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStill = context.reduceMotion;
    _pagesAbove = pagesAbove(context);
    _ambientPosition = _isPlaylist
        ? OnboardingAmbientScope.maybeOf(context)?.pagePosition
        : null;
  }

  /// The pager moved: tells the first page how far it has left, and the
  /// canvas where the pager is.
  void _onPagesMoved() {
    if (!_pages.hasClients) return;
    final value = _pages.page ?? _page.index.toDouble();
    _wordSlide.value = welcomeFirstPageSlide(value);
    _ambientPosition?.report(value);
  }

  @override
  void dispose() {
    _pages
      ..removeListener(_onPagesMoved)
      ..dispose();
    _wordSlide.dispose();
    _wordHeroDrawn.dispose();
    super.dispose();
  }

  Future<void> _readRingClaim() async {
    // The host answers "unsupported" when it cannot be reached, which
    // RingClaim reads as the quiet wording on an iPhone.
    final alarm = await getIt<AlarmHost>().authorizationStatus();
    if (mounted) setState(() => _ringClaim = RingClaim.forPhone(alarm));
  }

  /// Opens [page]: a slide like the end of a swipe, or at once with
  /// animations switched off.
  void _showPage(WelcomePage page) {
    if (page == _page) return;
    if (_followsFinger) {
      unawaited(
        _pages.animateToPage(
          page.index,
          duration: AppDurations.slow,
          curve: AppCurves.easeOut,
        ),
      );
    } else if (_pages.hasClients) {
      _pages.jumpToPage(page.index);
    } else {
      // No pictures on screen to move. Should they come back, they open on
      // this page.
      // No pager moves, so the canvas glides to the page's arrangement.
      _ambientPosition?.report(page.index.toDouble(), followsPager: false);
      _pages
        ..removeListener(_onPagesMoved)
        ..dispose();
      setState(() {
        _pages = PageController(initialPage: page.index)
          ..addListener(_onPagesMoved);
        _page = page;
        _restingOn = page;
      });
    }
  }

  /// The story on [page] is over: the next page opens, or the story plays
  /// again.
  void _onStoryDone(WelcomePage page) {
    if (!mounted) return;
    final next = welcomePageAfterStory(page, userHasMoved: _userHasMoved);
    if (next == page) {
      setState(() => _passes++);
    } else {
      _showPage(next);
    }
  }

  void _onNext() {
    _userHasMoved = true;
    _showPage(_page.next);
  }

  /// Follows the pictures as they move, to know which page is in front.
  bool _onPagesScroll(ScrollNotification scroll) {
    if (scroll is ScrollStartNotification) {
      setState(() {
        _isMoving = true;
        // Only a finger starts a scroll with a drag.
        if (scroll.dragDetails != null) _userHasMoved = true;
      });
    } else if (scroll is ScrollEndNotification) {
      final cameFrom = _restingOn;
      final index = _pages.page?.round() ?? _page.index;
      setState(() {
        _isMoving = false;
        _restingOn = WelcomePage.values[index];
      });
      if (_restingOn != cameFrom && !_isStill && isOnTopOfAll(_pagesAbove)) {
        AppHaptics.tick();
      }
    }
    return false;
  }

  void _onSwipeStart(DragStartDetails details) {
    _userHasMoved = true;
    _swiped = 0;
    if (_followsFinger) {
      _drag = _pages.position.drag(details, () => _drag = null);
    }
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    _swiped += details.primaryDelta ?? 0;
    _drag?.update(details);
  }

  void _onSwipeEnd(DragEndDetails details) {
    final drag = _drag;
    if (drag != null) {
      drag.end(details);
    } else {
      _showPage(welcomePageAfterSwipe(_page, moved: _swiped));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaylist) {
      return _IntroLayout(
        top: widget.isPreview ? _previewSwitch() : null,
        isHeroSpoken: true,
        hero: KeyedSubtree(
          key: ValueKey((_variant, _replays)),
          child: _spokenHeroFor(_variant),
        ),
        title: LocaleKeys.onboarding_welcome_title.tr(),
        subtitle: LocaleKeys.onboarding_welcome_subtitle.tr(),
        button: LocaleKeys.onboarding_welcome_button.tr(),
        onPressed: widget.isPreview
            ? () => context.pop()
            : () => unawaited(
                finishOnboardingStep(context, OnboardingStepId.welcome),
              ),
      );
    }

    final ringsOnSilent = _ringClaim == RingClaim.alarm;
    final button = welcomeButtonFor(_page);
    // A swipe anywhere on the page moves the pictures, also one that starts
    // on the words, which stay where they are.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // A screen reader moves the pages through the pictures and Next.
      excludeFromSemantics: true,
      onHorizontalDragStart: _onSwipeStart,
      onHorizontalDragUpdate: _onSwipeUpdate,
      onHorizontalDragEnd: _onSwipeEnd,
      onHorizontalDragCancel: () => _drag?.cancel(),
      child: ValueListenableBuilder<bool>(
        valueListenable: _wordHeroDrawn,
        builder: (context, isWordDrawn, _) => _IntroLayout(
          isHeroSpoken: true,
          isTitleHidden: isWordDrawn && _page == WelcomePage.rings,
          titleChoices: [
            LocaleKeys.onboarding_welcome_title.tr(),
            LocaleKeys.onboarding_welcome_rings_title.tr(),
            LocaleKeys.onboarding_welcome_widgets_title.tr(),
          ],
          hero: _storyPages(ringsOnSilent: ringsOnSilent),
          underHero: PermissionStepDots(
            count: WelcomePage.values.length,
            index: _page.index,
            label: LocaleKeys.onboarding_welcome_page_progress.tr(
              namedArgs: {
                'page': '${_page.index + 1}',
                'count': '${WelcomePage.values.length}',
              },
            ),
          ),
          // While page 1 draws its own title this one is hidden. It holds the
          // words of the next page, so it unfolds already reading right.
          title: switch (_page) {
            WelcomePage.rings =>
              isWordDrawn
                  ? LocaleKeys.onboarding_welcome_rings_title.tr()
                  : LocaleKeys.onboarding_welcome_title.tr(),
            WelcomePage.curl => LocaleKeys.onboarding_welcome_rings_title.tr(),
            WelcomePage.widgets =>
              LocaleKeys.onboarding_welcome_widgets_title.tr(),
          },
          subtitle: LocaleKeys.onboarding_welcome_subtitle.tr(),
          // Each page has its own line, in the place of the one line the
          // older animations share.
          caption: _StoryCaption(page: _page, ringsOnSilent: ringsOnSilent),
          button: switch (button) {
            WelcomeButton.next => LocaleKeys.onboarding_welcome_next.tr(),
            WelcomeButton.getStarted =>
              LocaleKeys.onboarding_welcome_button.tr(),
          },
          onPressed: switch (button) {
            WelcomeButton.next => _onNext,
            WelcomeButton.getStarted => () => unawaited(
              finishOnboardingStep(context, OnboardingStepId.welcome),
            ),
          },
        ),
      ),
    );
  }

  /// The three pictures side by side, one in view. They are as wide as the
  /// screen, wider than the room the layout gives them, so a picture slides
  /// off the edge of the screen and not off the edge of that room.
  Widget _storyPages({required bool ringsOnSilent}) => LayoutBuilder(
    builder: (context, box) => OverflowBox(
      minWidth: box.maxWidth + 2 * _IntroLayout.sidePadding,
      maxWidth: box.maxWidth + 2 * _IntroLayout.sidePadding,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onPagesScroll,
        // Swiping past the first or the last page does nothing: no bounce
        // and no stretch.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: PageView(
            controller: _pages,
            clipBehavior: Clip.none,
            physics: _isStill
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            onPageChanged: (index) =>
                setState(() => _page = WelcomePage.values[index]),
            children: [
              for (final page in WelcomePage.values)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _IntroLayout.sidePadding,
                  ),
                  child: _HeroStage(
                    isInFront: welcomePageIsInFront(
                      page,
                      restingOn: _restingOn,
                      isMoving: _isMoving,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey((page, _passes)),
                      child: _welcomeStoryHero(
                        page,
                        ringsOnSilent: ringsOnSilent,
                        onDone: () => _onStoryDone(page),
                        wordHeroDrawn: _wordHeroDrawn,
                        wordSlide: _wordSlide,
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

  /// Every animation by number, in two rows so fifteen still fit a phone.
  Widget _previewSwitch() {
    const perRow = 8;
    const all = WelcomeVariant.values;
    Widget row(List<WelcomeVariant> items) =>
        AppSegmentedControl<WelcomeVariant>(
          items: items,
          selectedItem: _variant,
          labelBuilder: (v) => '${v.index + 1}',
          onChanged: (v) => setState(() {
            _variant = v;
            _replays++;
          }),
        );
    return Column(
      children: [
        row(all.sublist(0, perRow)),
        const SizedBox(height: Spacing.s2),
        row(all.sublist(perRow)),
      ],
    );
  }
}

/// The hero for [variant] as a screen reader meets it. Every hero but one is
/// a mock-up of the app: its fake topic names and times mean nothing read
/// aloud, and the title and text below say what it shows. The sleeping face
/// answers a tap, so it labels itself.
Widget _spokenHeroFor(WelcomeVariant variant) =>
    variant == WelcomeVariant.wakeUp
    ? const _WakeUpHero()
    : ExcludeSemantics(child: _heroFor(variant));

/// Says whether the hero below is the one in front. On the welcome pages
/// only the page the user rests on is: its story starts and its haptic cues
/// play. A hero with no stage above it is always in front.
class _HeroStage extends InheritedWidget {
  const _HeroStage({required this.isInFront, required super.child});

  final bool isInFront;

  static bool isInFrontOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeroStage>()?.isInFront ??
      true;

  @override
  bool updateShouldNotify(_HeroStage old) => old.isInFront != isInFront;
}

/// Plays one animation cue on the phone.
void _playHeroCue(HeroCue cue) => switch (cue) {
  HeroCue.typeTick => AppHaptics.tick(),
  HeroCue.cardLands ||
  HeroCue.alertLands ||
  HeroCue.commandSent => AppHaptics.lightTap(),
  // The heavy thud. AppHaptics has no call named for a ring, and this is
  // its strongest.
  HeroCue.ringPulse => AppHaptics.success(),
};

Widget _heroFor(WelcomeVariant variant) => switch (variant) {
  WelcomeVariant.wakeUp => const _WakeUpHero(),
  WelcomeVariant.parade => const _ParadeHero(),
  WelcomeVariant.orbit => const _OrbitHero(),
  WelcomeVariant.ripple => const FaceRipple(),
  WelcomeVariant.peekaboo => const _PeekabooHero(),
  WelcomeVariant.curl => const _CurlHero(),
  WelcomeVariant.iphone => const _IphoneHero(),
  WelcomeVariant.android => const _AndroidHero(),
  WelcomeVariant.ladder => const _LadderHero(),
  WelcomeVariant.pipeline => const _PipelineHero(),
  WelcomeVariant.widgets => const _WidgetsHero(),
  WelcomeVariant.androidCurl => const _AndroidCurlHero(),
  WelcomeVariant.featureOrbit => const _FeatureOrbitHero(),
  WelcomeVariant.angryParade => const _AngryParadeHero(),
  WelcomeVariant.ringingOrbit => const _RingingOrbitHero(),
};

/// The shape every intro step shares: an animation filling the top, then a
/// title, a line of text and one button. The words and the button are on the
/// page from the first frame and stay put while the animation above them
/// plays and changes.
class _IntroLayout extends StatelessWidget {
  const _IntroLayout({
    required this.hero,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onPressed,
    this.top,
    this.badge,
    this.caption,
    this.underHero,
    this.isHeroSpoken = false,
    this.isTitleHidden = false,
    this.titleChoices = const [],
  });

  /// The room left free on each side of the page.
  static const double sidePadding = Spacing.s5;

  final Widget hero;

  /// True when [hero] gives a screen reader its own label. Otherwise it is
  /// a mock-up and a screen reader skips it.
  final bool isHeroSpoken;

  /// True when the animation draws the title itself. The small title then
  /// fades out, its row folds away and a screen reader skips it. It comes
  /// back as soon as this is false again.
  final bool isTitleHidden;

  /// Every title the page may show, when [title] changes with the page. The
  /// title row keeps the height of the tallest one, and [title] fades in
  /// place of the one before it.
  final List<String> titleChoices;
  final String title;
  final String subtitle;
  final String button;
  final VoidCallback onPressed;

  /// Above the animation, such as the preview switch.
  final Widget? top;

  /// Centred between the animation and the title, such as the page dots.
  final Widget? underHero;

  /// Between the title and the text, such as the Hosted badge.
  final Widget? badge;

  /// Drawn where [subtitle] would be, for a step whose line changes with
  /// its animation. It keeps one height, so nothing around it moves.
  final Widget? caption;

  /// The most the system text size may grow the title.
  static const double _titleMaxTextScale = 1.4;

  /// The small title. While [isTitleHidden] it fades out and its row folds
  /// away, so the animation can have the room. With animations switched off
  /// it goes at once.
  Widget _titleRow(BuildContext context, AppColors colors) {
    // The display size is already large. Capped, it holds to about three
    // lines at the largest system size, while the words below keep the full
    // scale.
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _titleMaxTextScale);
    final style = AppTypography.display(colors.onCanvas, fontSize: 36);
    Widget titleText(String text, {Key? key}) =>
        Text(text, key: key, textScaler: scaler, style: style);
    final shown = titleChoices.isEmpty
        ? titleText(title)
        : Stack(
            children: [
              // Every title, unseen, so the room is that of the tallest.
              for (final each in titleChoices.toSet())
                ExcludeSemantics(
                  child: Opacity(opacity: 0, child: titleText(each)),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: AnimatedSwitcher(
                  duration: context.motion(AppDurations.base),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  child: titleText(title, key: ValueKey(title)),
                ),
              ),
            ],
          );
    final row = Align(
      alignment: Alignment.topLeft,
      heightFactor: isTitleHidden ? 0 : 1,
      child: ExcludeSemantics(
        excluding: isTitleHidden,
        child: AnimatedOpacity(
          duration: context.motion(AppDurations.base),
          opacity: isTitleHidden ? 0 : 1,
          child: shown,
        ),
      ),
    );
    // A zero length AnimatedSize marks itself dirty while it lays out, which
    // a debug build reports. Without motion there is nothing to animate.
    if (context.reduceMotion) return row;
    return AnimatedSize(
      duration: AppDurations.base,
      curve: AppCurves.easeOut,
      alignment: Alignment.topCenter,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textScale = setupTextScaleOf(context);
    // This step has no top bar, so the shell's tracker, small face and Back
    // sit over the top of the page. The page starts under them, and the
    // animation gives up that much of its room, so the page is no taller.
    final trackerRoom = OnboardingAmbientScope.showsTrackerOf(context)
        ? AppScreenScaffold.topBarHeight - Spacing.s4
        : 0.0;

    // Same frame as the permissions and connect screens, so the button sits
    // in the same place on every onboarding step.
    return AppScreenScaffold(
      backgroundColor: Colors.transparent,
      withGhosts: false,
      withFades: false,
      hasTabBar: false,
      // Still while the words fit. At a large text size they take the room
      // the animation had, and then the page scrolls instead of cutting them
      // off behind the button.
      physics: const ClampingScrollPhysics(),
      // The column below fills the screen and keeps the button's room
      // itself, so the list adds none: the page moves only once the words
      // are taller than the screen.
      bodyClearsBottomBar: true,
      bottomBar: AppButton(
        label: button,
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: onPressed,
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            Spacing.s4 + trackerRoom,
            sidePadding,
            0,
          ),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              // The scaffold leaves room for the button under the list, but
              // SliverFillRemaining measures against the whole viewport, so
              // it carries that room itself: the lg button, the 12 under it
              // and the home indicator, plus a gap above the button.
              padding: EdgeInsets.only(
                bottom:
                    // The button grows with the system text size, so the
                    // room for it does too.
                    MediaQuery.textScalerOf(context).scale(60) +
                    12 +
                    MediaQuery.paddingOf(context).bottom +
                    12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (top != null) ...[
                    top!,
                    const SizedBox(height: Spacing.s4),
                  ],
                  Expanded(
                    child: _NoIntrinsicSize(
                      // The room the animation keeps depends on the text
                      // size: all of it at the default, none once the text
                      // is larger, so the words come first.
                      minHeight: introHeroMinHeightFor(
                        textScale,
                        roomAbove: trackerRoom,
                      ),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          // Too little room for it to read: it goes, and
                          // the words keep the page.
                          if (!introHeroFits(box.maxHeight)) {
                            return const SizedBox.shrink();
                          }
                          // It is a drawing, so it keeps its size when the
                          // system text grows.
                          final drawing = MediaQuery.withNoTextScaling(
                            child: AnimatedSwitcher(
                              duration: context.motion(
                                const Duration(milliseconds: 450),
                              ),
                              child: hero,
                            ),
                          );
                          // A mock-up; the words below carry the meaning.
                          return isHeroSpoken
                              ? drawing
                              : ExcludeSemantics(child: drawing);
                        },
                      ),
                    ),
                  ),
                  if (underHero != null) ...[
                    const SizedBox(height: Spacing.s3),
                    Center(child: underHero),
                  ],
                  const SizedBox(height: Spacing.s5),
                  _titleRow(context, colors),
                  if (badge != null) ...[
                    const SizedBox(height: Spacing.s3),
                    Align(alignment: Alignment.centerLeft, child: badge),
                  ],
                  const SizedBox(height: Spacing.s2),
                  caption ??
                      Text(
                        subtitle,
                        style: AppTypography.lead(
                          colors.onCanvasMuted,
                          fontSize: 16,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A hero that redraws every frame and knows how many seconds it has run.
/// With animations switched off it sits at [restAt] and runs no ticker at
/// all. On a welcome page that is not in front yet it waits at its first
/// frame, and its clock starts when the page comes to rest.
abstract class _ClockState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _seconds = 0;

  /// Where a still hero rests: after the intro, on a friendly face.
  double get restAt;

  /// True while the hero is asked to hold still: the phone asks for reduced
  /// motion.
  bool _isStill = false;

  /// Seconds since the hero appeared.
  double get t => _isStill ? restAt : _seconds;

  /// The haptic cues this hero plays, timed on its own clock. Most heroes
  /// have none.
  List<TimedCue> buildCues() => const [];

  /// How many seconds one pass of this hero's story takes, when the story
  /// starts over and has cues. The cues then play again on every pass.
  double? get loopTakes => null;

  late final HeroCueClock _cueClock = HeroCueClock(
    buildCues(),
    loopsEvery: loopTakes,
  );

  List<ModalRoute<Object?>> _pagesAbove = const [];

  /// Whether this hero is the one in front (see [_HeroStage]).
  bool _isInFront = true;

  /// Whether this hero may play a haptic right now: it moves, it is the one
  /// in front, its screen is the one on top, and the app is in front. A hero
  /// whose screen is covered or gone stays silent, and so does one on a page
  /// that is half in view during a swipe.
  bool get canPlayHaptics {
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    return mounted &&
        !_isStill &&
        _isInFront &&
        isOnTopOfAll(_pagesAbove) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  /// Called on every frame, after the clock has moved to [seconds].
  void onClock(double seconds) {}

  /// Whether [cue] may play now that it is due. A hero whose story the user
  /// can cut short says no to what is left of it.
  bool mayPlay(HeroCue cue) => true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final seconds = elapsed.inMicroseconds / 1e6;
      setState(() => _seconds = seconds);
      onClock(seconds);
      // The cue clock moves on every frame, allowed to play or not, so a
      // cue that was missed is never kept for later.
      final cues = _cueClock.advanceTo(seconds);
      if (canPlayHaptics) cues.where(mayPlay).forEach(_playHeroCue);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStill = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _pagesAbove = pagesAbove(context);
    _isInFront = _HeroStage.isInFrontOf(context);
    // The ticker is stopped, not just ignored: a frame callback that
    // does nothing still wakes the engine every frame.
    if (_isStill && _ticker.isActive) {
      _ticker.stop();
    } else if (!_isStill && !_ticker.isActive && _isInFront) {
      // A story that has started plays on while its page is swiped away.
      // One that has not waits for its page to come to rest.
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Face helpers.

final Map<FaceState, FaceShape> _shapes = {};

FaceShape _shape(FaceState state) =>
    _shapes.putIfAbsent(state, () => faceFor(state));

/// How far through the window starting at [start] and lasting [length] the
/// clock [t] is, from 0 to 1.
double _window(double t, double start, double length) =>
    ((t - start) / length).clamp(0.0, 1.0);

FaceShape _blend(FaceState a, FaceState b, double p) => FaceShape.lerp(
  _shape(a),
  _shape(b),
  Curves.easeInOutCubic.transform(p),
);

/// Walks [faces] in a loop: holds each one, then melts into the next.
FaceShape _cycle(
  List<FaceState> faces,
  double t, {
  double hold = 1.6,
  double blend = 0.45,
}) {
  final step = hold + blend;
  final local = t % (step * faces.length);
  final i = local ~/ step;
  final into = local - i * step;
  final from = faces[i];
  final to = faces[(i + 1) % faces.length];
  return into < hold ? _shape(from) : _blend(from, to, (into - hold) / blend);
}

/// A quick blink every few seconds, so a face that is holding still still
/// looks alive. [offset] keeps a crowd of faces from blinking together.
FaceShape _withBlink(FaceShape face, double t, {double offset = 0}) {
  final local = (t + offset) % 3.7;
  return local < 0.12 ? face.blinking : face;
}

const Color _darkInk = faceCrowdInk;

/// Bright heads for the crowd variants. Dark ink on all of them, so they
/// read the same in light and dark mode.
const List<Color> _crowdFills = faceCrowdFills;

Widget _face(FaceShape shape, double size, {Color? fill}) => FaceWidget(
  state: FaceState.calm,
  shape: shape,
  size: size,
  overrideFillColor: fill,
  overrideStrokeColor: fill == null ? null : _darkInk,
  overrideInkColor: fill == null ? null : _darkInk,
);

// ---------------------------------------------------------------------------
// 1. Wake up.

class _WakeUpHero extends StatefulWidget {
  const _WakeUpHero();

  @override
  State<_WakeUpHero> createState() => _WakeUpHeroState();
}

class _WakeUpHeroState extends _ClockState<_WakeUpHero> {
  /// A still hero rests this long after waking, on its first smile.
  @override
  double get restAt => 1.6;

  /// When the face woke, on the hero's clock. Null while it dozes.
  double? _wokeAt;

  /// Wakes the face now. The hop starts on the next frame and the thump
  /// plays here, so a tap feels answered at once.
  void _wake() {
    if (_isStill || _wokeAt != null) return;
    setState(() => _wokeAt = _seconds);
    if (canPlayHaptics) AppHaptics.capture();
  }

  @override
  void onClock(double seconds) {
    if (seconds >= welcomeAutoWakeAfter) _wake();
  }

  static const List<FaceState> _after = [
    FaceState.happy,
    FaceState.curious,
    FaceState.cheeky,
    FaceState.love,
    FaceState.content,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final enter = Curves.easeOutBack.transform(_window(t, 0, 0.9));

    // A still hero has been awake all along.
    final wokeAt = _isStill ? 0.0 : _wokeAt;
    final isAwake = wokeAt != null;
    // Seconds since it woke. Below zero while it dozes.
    final awake = isAwake ? t - wokeAt : -1.0;

    final FaceShape face;
    if (awake < 0) {
      face = _shape(FaceState.dozing);
    } else if (awake < 0.35) {
      face = _blend(FaceState.dozing, FaceState.wakesUp, awake / 0.35);
    } else if (awake < 0.9) {
      face = _shape(FaceState.wakesUp);
    } else if (awake < 1.3) {
      face = _blend(
        FaceState.wakesUp,
        FaceState.happy,
        _window(awake, 0.9, 0.4),
      );
    } else {
      face = _withBlink(_cycle(_after, awake - 1.3, hold: 2), t);
    }

    // A startled hop as it wakes, then a slow breathing bob.
    final hop = isAwake
        ? math.sin(_window(awake, 0, welcomeWakeHopTakes) * math.pi) * -26
        : 0.0;
    final bob = awake > 1.3 ? math.sin((awake - 1.3) * 2.2) * 5 : 0.0;

    return Semantics(
      container: true,
      image: true,
      label: isAwake
          ? LocaleKeys.onboarding_welcome_hero_awake.tr()
          : LocaleKeys.onboarding_welcome_hero_asleep.tr(),
      hint: isAwake ? null : LocaleKeys.onboarding_welcome_hero_wake_hint.tr(),
      onTap: isAwake ? null : _wake,
      child: Listener(
        // A touch anywhere on the hero wakes it, on the way down: waiting
        // for the finger to lift would make the face feel slow.
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _wake(),
        child: Center(
          child: Opacity(
            opacity: _window(t, 0, 0.4),
            child: Transform.translate(
              offset: Offset(0, hop + bob),
              child: Transform.scale(
                scale: 0.6 + 0.4 * enter,
                child: ExcludeSemantics(child: _face(face, 190)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Parade.

class _ParadeHero extends StatefulWidget {
  const _ParadeHero();

  @override
  State<_ParadeHero> createState() => _ParadeHeroState();
}

class _ParadeHeroState extends _ClockState<_ParadeHero> {
  @override
  double get restAt => 2.2;

  static const List<FaceState> _moods = [
    FaceState.happy,
    FaceState.cheeky,
    FaceState.love,
    FaceState.proud,
    FaceState.laughing,
    FaceState.content,
    FaceState.curious,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    return LayoutBuilder(
      builder: (context, box) {
        const count = 5;
        const gap = 8.0;
        final size = math.min<double>(
          72,
          (box.maxWidth - gap * (count - 1)) / count,
        );
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _member(i, size, t, box.maxWidth),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _member(int i, double size, double t, double width) {
    final enter = Curves.easeOutBack.transform(_window(t, 0.12 * i, 0.8));
    final slide = (1 - enter) * width;

    // After everyone is in, a wave runs left to right, over and over.
    final wave = (t - 1.4 - i * 0.14) % 2.4;
    final hop = t > 1.4 && wave < 0.5
        ? math.sin(wave / 0.5 * math.pi) * -24
        : 0.0;

    final face = _withBlink(
      _cycle(_moods, t + i * 0.7, hold: 1.8),
      t,
      offset: i * 0.9,
    );
    return Transform.translate(
      offset: Offset(slide, hop),
      child: _face(face, size, fill: _crowdFills[i % _crowdFills.length]),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Orbit.

class _OrbitHero extends StatefulWidget {
  const _OrbitHero();

  @override
  State<_OrbitHero> createState() => _OrbitHeroState();
}

class _OrbitHeroState extends _ClockState<_OrbitHero> {
  @override
  double get restAt => 2;

  static const List<FaceState> _centre = [
    FaceState.calm,
    FaceState.happy,
    FaceState.lookLeft,
    FaceState.lookRight,
    FaceState.proud,
  ];

  static const List<FaceState> _moons = [
    FaceState.happy,
    FaceState.love,
    FaceState.cheeky,
    FaceState.surprised,
    FaceState.laughing,
    FaceState.content,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight);
        final big = side * 0.4;
        final small = side * 0.15;
        final radius = side / 2 - small / 2 - 4;
        const count = 6;

        final centreIn = Curves.easeOutBack.transform(_window(t, 0, 0.7));
        final centreFace = _withBlink(_cycle(_centre, t, hold: 1.7), t);

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  _moon(i, count, t, radius, small),
                Transform.scale(
                  scale: centreIn,
                  child: _face(centreFace, big),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _moon(int i, int count, double t, double radius, double size) {
    final out = Curves.easeOutBack.transform(_window(t, 0.3 + i * 0.08, 0.9));
    final angle = i * 2 * math.pi / count + t * 0.45 - math.pi / 2;
    final r = radius * out;
    final face = _withBlink(
      _cycle(_moons, t + i * 0.8, hold: 1.5),
      t,
      offset: i * 0.6,
    );
    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
      child: Opacity(
        opacity: out.clamp(0.0, 1.0),
        child: _face(face, size, fill: _crowdFills[i % _crowdFills.length]),
      ),
    );
  }
}

// 4. Ripple lives in lib/design/faces/face_ripple.dart (FaceRipple), shared
// with the test alarm's acknowledged screen.

// ---------------------------------------------------------------------------
// 5. Peekaboo.

class _PeekabooHero extends StatefulWidget {
  const _PeekabooHero();

  @override
  State<_PeekabooHero> createState() => _PeekabooHeroState();
}

class _PeekabooHeroState extends _ClockState<_PeekabooHero> {
  @override
  double get restAt => 3.4;

  static const List<FaceState> _after = [
    FaceState.love,
    FaceState.happy,
    FaceState.cheeky,
    FaceState.content,
  ];

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    final colors = context.appColors;

    final FaceShape face;
    if (t < 1.3) {
      face = _shape(FaceState.lookLeft);
    } else if (t < 1.6) {
      face = _blend(
        FaceState.lookLeft,
        FaceState.lookRight,
        _window(t, 1.3, 0.3),
      );
    } else if (t < 2.1) {
      face = _shape(FaceState.lookRight);
    } else if (t < 2.3) {
      face = _blend(
        FaceState.lookRight,
        FaceState.realization,
        _window(t, 2.1, 0.2),
      );
    } else if (t < 2.6) {
      face = _shape(FaceState.realization);
    } else if (t < 3) {
      face = _blend(
        FaceState.realization,
        FaceState.love,
        _window(t, 2.6, 0.4),
      );
    } else {
      face = _withBlink(_cycle(_after, t - 3, hold: 2), t);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min<double>(210, box.maxHeight * 0.8);
        // Hidden below the ledge, then the top of the head peeks over it,
        // then the whole face pops up.
        final peek = Curves.easeOutCubic.transform(_window(t, 0.2, 0.7));
        final pop = Curves.easeOutBack.transform(_window(t, 2.5, 0.6));
        final shown = 0.42 * peek + 0.58 * pop;
        final bob = t > 3.1 ? math.sin((t - 3.1) * 2.2) * 4 : 0.0;
        final ledgeY = box.maxHeight * 0.5 + size / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: ledgeY,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: (box.maxWidth - size) / 2,
                      top: ledgeY - size * shown + bob,
                      child: _face(face, size),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: box.maxWidth * 0.12,
              right: box.maxWidth * 0.12,
              top: ledgeY,
              child: Opacity(
                opacity: _window(t, 0, 0.3),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onCanvas,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Answers "how big do you want to be" with [minHeight] (zero by default),
/// so a scroll view that asks (SliverFillRemaining does) never reaches the
/// LayoutBuilder inside the animations, which cannot answer it. The
/// animations fill whatever room they are given anyway. A [minHeight] above
/// zero is the room the page keeps for them when other things on the page
/// grow.
class _NoIntrinsicSize extends SingleChildRenderObjectWidget {
  const _NoIntrinsicSize({required Widget super.child, this.minHeight = 0});

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoIntrinsicSize(minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNoIntrinsicSize renderObject,
  ) {
    renderObject.minHeight = minHeight;
  }
}

class _RenderNoIntrinsicSize extends RenderProxyBox {
  _RenderNoIntrinsicSize(this._minHeight);

  double _minHeight;

  double get minHeight => _minHeight;

  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight;
}
