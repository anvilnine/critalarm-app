import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/pass_page.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/components/pass_stack.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

// The Personalize pieces: the pass card, the stack, the page scaffold and the
// grow between them, each with demo data. Every section is its own widget so
// the capture tool can draw one at a time. The words are made up for the
// gallery.

/// The four sections, one after another.
class PassesSection extends StatelessWidget {
  const PassesSection({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    key: ValueKey('gallery-passes'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PassCardsGallery(),
      SizedBox(height: 48),
      PassStackGallery(),
      SizedBox(height: 48),
      PassPageGallery(),
      SizedBox(height: 48),
      PassFramesGallery(),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.note);

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headline(colors.onCanvas)),
          const SizedBox(height: Spacing.s2),
          Text(note, style: AppTypography.body(colors.onCanvasMuted)),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.s3, bottom: Spacing.s1),
    child: Text(
      text,
      style: AppTypography.mono(
        context.appColors.onCanvasMuted,
        fontSize: 11,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Demo data.
// ---------------------------------------------------------------------------

/// What a made-up pass says.
class PassDemo {
  const PassDemo({
    required this.pass,
    required this.label,
    required this.value,
    this.tag,
    this.isOn = true,
  });

  final PassId pass;
  final String label;
  final String value;
  final String? tag;
  final bool isOn;

  PassTone tone(AppColors colors) => passToneFor(pass, colors);

  PassDemo withValue(String value) => PassDemo(
    pass: pass,
    label: label,
    value: value,
    tag: tag,
    isOn: isOn,
  );
}

/// The five passes of a free phone, in stack order.
const List<PassDemo> kPassDemos = [
  PassDemo(pass: PassId.look, label: 'Look', value: 'Standard'),
  PassDemo(pass: PassId.sound, label: 'Sound', value: 'Classic siren'),
  PassDemo(
    pass: PassId.challenge,
    label: 'Wake-up challenge',
    value: 'Off',
    tag: 'Pro',
    isOn: false,
  ),
  PassDemo(pass: PassId.widgets, label: 'Widgets', value: '3', tag: 'Pro'),
  PassDemo(
    pass: PassId.appIcon,
    label: 'App icon',
    value: 'Default',
    tag: 'Hosted',
  ),
];

/// A thumbnail drawn in code, about the size of the real ones.
WidgetBuilder passDemoThumbnail(PassId pass) => switch (pass) {
  PassId.look => (context) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: kPassThumbWidth,
        height: 118,
        decoration: BoxDecoration(
          color: colors.critCanvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.ink, width: 3),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 12),
        child: const FaceWidget(state: FaceState.calm, size: 36),
      ),
    );
  },
  PassId.sound => (context) {
    final colors = context.appColors;
    const heights = [22.0, 44.0, 60.0, 36.0, 52.0, 28.0, 46.0, 18.0];
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final h in heights)
            Container(
              width: 5,
              height: h,
              decoration: BoxDecoration(
                color: colors.onHighlight,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
        ],
      ),
    );
  },
  PassId.challenge => (context) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'pro',
                style: TextStyle(color: colors.yellow),
              ),
              TextSpan(
                text: 'd-db',
                style: TextStyle(color: colors.onPanelMuted),
              ),
            ],
          ),
          style: AppTypography.monoBold(colors.onPanelMuted),
        ),
      ),
    );
  },
  PassId.widgets => (context) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: kPassThumbWidth,
        height: kPassThumbWidth,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.inkFixed.withValues(alpha: 0.16),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '3',
          style: AppTypography.headline(colors.ink, fontSize: 26),
        ),
      ),
    );
  },
  PassId.appIcon => (context) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: kPassThumbWidth,
        height: kPassThumbWidth,
        decoration: BoxDecoration(
          color: colors.high,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 30,
          height: 34,
          decoration: BoxDecoration(
            color: colors.yellow,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: colors.inkFixed, width: 4),
          ),
        ),
      ),
    );
  },
};

List<AppPassCard> _cards(BuildContext context, List<PassDemo> demos) {
  final colors = context.appColors;
  return [
    for (final demo in demos)
      AppPassCard(
        pass: demo.pass,
        tone: demo.tone(colors),
        label: demo.label,
        value: demo.value,
        tag: demo.tag,
        isOn: demo.isOn,
        thumbnail: passDemoThumbnail(demo.pass),
        onTap: (_) {},
      ),
  ];
}

// ---------------------------------------------------------------------------
// The cards.
// ---------------------------------------------------------------------------

/// Each pass card on its own, with and without a tag, a two-line value and a
/// long name, in the overlapped form and the flat one.
class PassCardsGallery extends StatelessWidget {
  const PassCardsGallery({super.key});

  Widget _card(
    BuildContext context,
    PassDemo demo, {
    bool hasThumb = true,
    bool isFlat = false,
  }) {
    // The stack stops overlapping from text scale 1.3, and so do these.
    final flat =
        isFlat ||
        MediaQuery.textScalerOf(context).scale(100) / 100 >=
            kChromeMaxTextScale;
    final card = AppPassCard(
      pass: demo.pass,
      tone: demo.tone(context.appColors),
      label: demo.label,
      value: demo.value,
      tag: demo.tag,
      isOn: demo.isOn,
      thumbnail: hasThumb ? passDemoThumbnail(demo.pass) : null,
      onTap: (_) {},
    );
    return PassCardLayout(
      isFlat: flat,
      child: flat ? card : SizedBox(height: 150, child: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    const challenge = PassDemo(
      pass: PassId.challenge,
      label: 'Wake-up challenge',
      value: 'Type the alert title',
      tag: 'Pro',
    );
    const longSound = PassDemo(
      pass: PassId.sound,
      label: 'Sound',
      value: 'My recording of the kitchen timer going off at six',
    );
    return Column(
      key: const ValueKey('gallery-pass-cards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          'Pass cards',
          'One card per setting: a mono label, a lock badge with the plan word '
              'while the feature is locked, the value, a thumbnail. The badge '
              'is yellow where that reads on the ground and the text colour of '
              'the card where it does not. A card is 260 points tall in '
              'the stack and shows a 134 point band. It is drawn here 150 '
              'points tall.',
        ),
        const _Caption('the five passes'),
        for (final demo in kPassDemos) ...[
          _card(context, demo),
          const SizedBox(height: Spacing.s3),
        ],
        const _Caption('with a badge, and the same card without one'),
        _card(context, kPassDemos[3]),
        const SizedBox(height: Spacing.s3),
        _card(
          context,
          const PassDemo(pass: PassId.widgets, label: 'Widgets', value: '3'),
          hasThumb: false,
        ),
        const _Caption('a badge on the red look ground'),
        _card(
          context,
          const PassDemo(
            pass: PassId.look,
            label: 'Look',
            value: 'Standard',
            tag: 'Pro',
          ),
        ),
        const _Caption('a challenge that is on: the value is yellow'),
        _card(context, challenge),
        const _Caption('a two-line value, then a long own-sound name'),
        _card(context, challenge.withValue('Type the topic name')),
        const SizedBox(height: Spacing.s3),
        _card(context, longSound),
        const _Caption('flat, as the stack draws them from text scale 1.3'),
        _card(context, challenge, isFlat: true),
        const SizedBox(height: Spacing.s3),
        _card(context, longSound, isFlat: true),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The stack.
// ---------------------------------------------------------------------------

/// The header row and the stack on a display of [size], with the inset and
/// text size of that display.
class PassStackDemo extends StatelessWidget {
  const PassStackDemo({
    required this.size,
    this.safeTop = 47,
    this.safeBottom = 34,
    this.textScale = 1,
    this.count = 5,
    super.key,
  });

  final Size size;
  final double safeTop;
  final double safeBottom;
  final double textScale;

  /// How many passes: five on a phone, three on the web.
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = EdgeInsets.only(top: safeTop, bottom: safeBottom);
    final demos = [
      kPassDemos[0],
      kPassDemos[1],
      if (count > 2) kPassDemos[2],
      if (count > 3) kPassDemos[3],
      if (count > 4) kPassDemos[4],
    ].take(count).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        padding: padding,
        viewPadding: padding,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: ColoredBox(
          color: colors.canvas,
          child: AppPassStack(
            title: 'Personalize',
            backLabel: 'Back to Settings',
            groupLabel: 'Passes',
            cards: _cards(context, demos),
          ),
        ),
      ),
    );
  }
}

/// The stack at widths 320, 390 and 600, then at text scale 1.3 and 2.0.
class PassStackGallery extends StatelessWidget {
  const PassStackGallery({super.key});

  @override
  Widget build(BuildContext context) {
    const shots = <(String, Size, double, double)>[
      ('320 wide', Size(320, 640), 24, 1),
      ('390 wide', Size(390, 844), 47, 1),
      ('600 wide', Size(600, 844), 24, 1),
      ('390 wide, text 1.3: flat', Size(390, 1500), 47, 1.3),
      ('390 wide, text 2.0: flat', Size(390, 1900), 47, 2),
    ];
    return Column(
      key: const ValueKey('gallery-pass-stack'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Pass stack',
          'The Personalize root. Cards overlap under text scale 1.3 and '
              'stand in a column from 1.3. The ground fills the display and '
              'the stack sits in a column up to 560 wide.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (name, size, top, scale) in shots)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Caption(name),
                      PassStackDemo(
                        size: size,
                        safeTop: top,
                        textScale: scale,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The page.
// ---------------------------------------------------------------------------

/// Which page header to draw.
enum PassPageVariant {
  /// A short value, a state word and a trailing control.
  sound,

  /// A three-line value at 320 wide, a tag and a foot line.
  challenge,

  /// A tag, a body and a bottom bar with two buttons.
  widgets,

  /// A tag, and the pinned action.
  appIcon,

  /// The look colour, a trailing control.
  look,

  /// An own sound with a name that runs to three lines.
  longValue,
}

/// A pass page on a display of [size], drawn with sample content.
class PassPageDemo extends StatelessWidget {
  const PassPageDemo({
    required this.variant,
    required this.size,
    this.safeTop = 47,
    this.safeBottom = 34,
    this.textScale = 1,
    super.key,
  });

  final PassPageVariant variant;
  final Size size;
  final double safeTop;
  final double safeBottom;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.only(top: safeTop, bottom: safeBottom);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        padding: padding,
        viewPadding: padding,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox.fromSize(size: size, child: _page(context)),
    );
  }

  Widget _page(BuildContext context) {
    final colors = context.appColors;
    Widget sheet(List<String> rows) => SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    row,
                    style: AppTypography.lead(colors.ink, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    Widget play() => Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: colors.yellow, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: AppGlyph(GlyphType.play, size: 18, color: colors.ink),
    );
    return switch (variant) {
      PassPageVariant.sound => AppPassPage(
        tone: passToneFor(PassId.sound, colors),
        label: 'Sound',
        value: 'Classic siren',
        state: 'playing',
        trailing: play(),
        slivers: [
          sheet([
            'Classic siren',
            'Pulsing klaxon',
            'Hi-lo siren',
            'Endless climb',
            'Deep horn',
            'Two tone',
            'Slow wail',
            'Fast bleep',
            'Foghorn',
            'Rising alarm',
          ]),
        ],
      ),
      PassPageVariant.challenge => AppPassPage(
        tone: passToneFor(PassId.challenge, colors),
        label: 'Wake-up challenge',
        value: 'Type the alert title',
        tag: 'Pro',
        foot: "I'm up always stops the alarm with one tap.",
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: colors.panelLine),
                ),
              ),
            ),
          ),
        ],
      ),
      PassPageVariant.widgets => AppPassPage(
        tone: passToneFor(PassId.widgets, colors),
        label: 'Widgets',
        value: '3',
        tag: 'Pro',
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        bottomBar: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(label: 'See Pro', isFullWidth: true, onPressed: () {}),
              const SizedBox(height: 8),
              AppButton(
                label: 'How to add one',
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
      PassPageVariant.appIcon => AppPassPage(
        tone: passToneFor(PassId.appIcon, colors),
        label: 'App icon',
        value: 'Default',
        tag: 'Hosted',
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: passDemoThumbnail(PassId.appIcon)(context)),
            ),
          ),
        ],
        bottomBar: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: AppButton(
            label: 'Unlock',
            isFullWidth: true,
            onPressed: () {},
          ),
        ),
      ),
      PassPageVariant.look => AppPassPage(
        tone: passToneFor(PassId.look, colors),
        label: 'Look',
        value: 'Standard',
        trailing: play(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(child: passDemoThumbnail(PassId.look)(context)),
            ),
          ),
        ],
      ),
      PassPageVariant.longValue => AppPassPage(
        tone: passToneFor(PassId.sound, colors),
        label: 'Sound',
        value: 'My recording of the kitchen timer going off at six',
        slivers: [
          sheet(['Classic siren', 'Pulsing klaxon', 'Hi-lo siren']),
        ],
      ),
    };
  }
}

/// The page header variants at 390 by 844.
class PassPageGallery extends StatelessWidget {
  const PassPageGallery({super.key});

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('gallery-pass-page'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading(
        'Pass page',
        'The ground in the pass colour, a pinned ring at the top left, the '
            'header block (label, state word, tag, value, foot), the body '
            'and an optional bottom bar. The value wraps and is never cut.',
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final variant in PassPageVariant.values)
              Padding(
                padding: const EdgeInsets.only(right: Spacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Caption(variant.name),
                    PassPageDemo(
                      variant: variant,
                      size: const Size(390, 844),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// The transition.
// ---------------------------------------------------------------------------

/// One frame of the grow, 390 by 844, drawn from [passFrameAt] over a root.
///
/// It uses the real cards and page: the stack gets a [PassHandoff] held at
/// [progress], so the card that is open hides and the others slide away as
/// they do under the route.
class PassFramePreview extends StatefulWidget {
  const PassFramePreview({
    required this.progress,
    this.reverse = false,
    this.pass = PassId.sound,
    this.reduceMotion = false,
    this.scale = 0.6,
    super.key,
  });

  /// The route's progress, 0 closed to 1 open.
  final double progress;

  /// Whether the route is closing.
  final bool reverse;

  /// Which card is open. Sound, widgets or challenge show a page.
  final PassId pass;

  final bool reduceMotion;

  /// How much the 390 by 844 frame is shrunk.
  final double scale;

  @override
  State<PassFramePreview> createState() => _PassFramePreviewState();
}

class _PassFramePreviewState extends State<PassFramePreview> {
  final PassHandoff _handoff = PassHandoff();

  @override
  void dispose() {
    _handoff.dispose();
    super.dispose();
  }

  static PassPageVariant _variantFor(PassId pass) => switch (pass) {
    PassId.look => PassPageVariant.look,
    PassId.sound => PassPageVariant.sound,
    PassId.challenge => PassPageVariant.challenge,
    PassId.widgets => PassPageVariant.widgets,
    PassId.appIcon => PassPageVariant.appIcon,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const display = PassDisplay.phone;
    final layout = PassStackLayout.of(
      width: display.size.width,
      height: display.size.height,
      textScale: 1,
      count: 5,
      safeTop: display.safeTop,
    );
    final index = PassId.values.indexOf(widget.pass);
    final demo = kPassDemos[index];
    final origin = PassOrigin(
      pass: widget.pass,
      rect: Rect.fromLTWH(
        layout.cardLeft,
        layout.tops[index],
        layout.cardWidth,
        layout.heights[index],
      ),
      tone: demo.tone(colors),
      label: demo.label,
      value: demo.value,
      display: display,
      thumbnail: passDemoThumbnail(widget.pass),
      visibleHeight: index == kPassDemos.length - 1 ? null : layout.step,
      reduceMotion: widget.reduceMotion,
    );
    final frame = passFrameAt(widget.progress, origin, reverse: widget.reverse);
    _handoff.attach(
      pass: widget.pass,
      animation: AlwaysStoppedAnimation(widget.progress),
      frame: () => frame,
    );
    return SizedBox(
      width: display.size.width * widget.scale,
      height: display.size.height * widget.scale,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: display.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: display.size,
                  padding: EdgeInsets.only(top: display.safeTop, bottom: 34),
                  viewPadding: EdgeInsets.only(
                    top: display.safeTop,
                    bottom: 34,
                  ),
                  textScaler: TextScaler.noScaling,
                ),
                child: ColoredBox(
                  color: colors.canvas,
                  child: AppPassStack(
                    title: 'Personalize',
                    backLabel: 'Back to Settings',
                    handoff: _handoff,
                    cards: _cards(context, kPassDemos),
                  ),
                ),
              ),
              PassGrow(
                frame: frame,
                origin: origin,
                child: PassPageDemo(
                  variant: _variantFor(widget.pass),
                  size: display.size,
                  safeTop: display.safeTop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grow as a row of frames at 0, 0.25, 0.5, 0.75 and 1, open and back,
/// with a slider for any point between.
class PassFramesGallery extends StatefulWidget {
  const PassFramesGallery({super.key});

  @override
  State<PassFramesGallery> createState() => _PassFramesGalleryState();
}

class _PassFramesGalleryState extends State<PassFramesGallery> {
  static const _steps = [0.0, 0.25, 0.5, 0.75, 1.0];

  double _progress = 0.4;
  bool _isReverse = false;
  PassId _pass = PassId.sound;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      key: const ValueKey('gallery-pass-frames'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Open and close',
          'The card grows into its page over 520 ms; the route takes 600 ms '
              'in and 520 ms back. These are the frames at five points of '
              'the route, drawn from the same function the route uses. '
              'Under reduce motion the finished page fades in and nothing '
              'grows.',
        ),
        for (final reverse in [false, true]) ...[
          _Caption(reverse ? 'closing' : 'opening'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final step in _steps)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.s3),
                    child: PassFramePreview(
                      progress: step,
                      reverse: reverse,
                      pass: _pass,
                      reduceMotion: context.reduceMotion,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const _Caption('any point'),
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Opening')),
                ButtonSegment(value: true, label: Text('Closing')),
              ],
              selected: {_isReverse},
              onSelectionChanged: (value) =>
                  setState(() => _isReverse = value.first),
            ),
            const SizedBox(width: Spacing.s3),
            SegmentedButton<PassId>(
              segments: const [
                ButtonSegment(
                  value: PassId.challenge,
                  label: Text('Challenge'),
                ),
                ButtonSegment(value: PassId.sound, label: Text('Sound')),
                ButtonSegment(value: PassId.widgets, label: Text('Widgets')),
              ],
              selected: {_pass},
              onSelectionChanged: (value) =>
                  setState(() => _pass = value.first),
            ),
          ],
        ),
        Slider(
          value: _progress,
          onChanged: (value) => setState(() => _progress = value),
        ),
        Text(
          'progress ${_progress.toStringAsFixed(2)}',
          style: AppTypography.mono(colors.onCanvasMuted, fontSize: 11),
        ),
        PassFramePreview(
          progress: _progress,
          reverse: _isReverse,
          pass: _pass,
          reduceMotion: context.reduceMotion,
          scale: 0.8,
        ),
      ],
    );
  }
}
