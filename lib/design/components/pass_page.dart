import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_app_profiles.dart';
import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// The back ring's size.
const double kPassRingSize = 44;

/// The ring's distance from the left edge of the column, and from the inset.
const double kPassRingLeft = 16;
const double kPassRingTop = 5;

/// How far below the ring the pinned strip reaches, and how soft its edge is.
const double _kStripBelowRing = 8;
const double _kStripEdge = 16;

/// A 44 point ring with a back chevron in it: the way out of a pass page, and
/// the first stop on it. The stack uses it too, for the way back to Settings.
///
/// [color] is the text colour of the surface under it. The ring is 2 points
/// wide.
class PassBackRing extends StatefulWidget {
  const PassBackRing({
    required this.color,
    required this.label,
    required this.onTap,
    super.key,
  });

  final Color color;

  /// What a screen reader says, such as "Back to Personalize".
  final String label;

  final VoidCallback onTap;

  @override
  State<PassBackRing> createState() => _PassBackRingState();
}

class _PassBackRingState extends State<PassBackRing> {
  bool _isFocused = false;

  void _activate() {
    AppHaptics.selection();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    onTap: _activate,
    excludeSemantics: true,
    child: FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _isFocused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _activate,
        child: SizedBox.square(
          dimension: kPassRingSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // A focused ring is thicker, so a keyboard can see where it is.
              border: Border.all(
                color: widget.color,
                width: _isFocused ? 4 : 2,
              ),
            ),
            child: Center(
              child: AppGlyph(GlyphType.back, size: 20, color: widget.color),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The scaffold of a Personalize pass page.
///
/// From the back to the front:
///
/// 1. The ground, in the pass colour, full bleed and opaque. It also sets an
///    ambient override of the same colour, so the canvas under the page is
///    that colour too (`AmbientAppProfiles.passGround`).
/// 2. The body: [slivers], which scroll under the pinned row.
/// 3. The pinned top row: a strip in the ground colour down to the ring's
///    bottom plus 8 points with a soft 16 point edge, holding the back ring
///    at the left and the optional [trailing] control at the right.
/// 4. The header block, the first thing in the scroll view: the label (with
///    a [state] word and a [tag]), the value at 42 points, an optional
///    [foot].
/// 5. The optional [bottomBar], pinned, on the ground colour.
///
/// Everything sits in a column `min(width, 560)` wide, centred; the ground
/// fills the display.
///
/// The page reads the route's [PassFrameScope]. While the page grows out of a
/// card, the header block rides from the card's place to its own with the
/// value size, the ring and the body fade in, and the card's thumbnail flies
/// behind them. With no scope (the page opened without a card, or drawn on
/// its own) it is the finished page. The screen using it knows nothing of
/// the transition.
///
/// Order for a screen reader: the back ring, the trailing control, the header
/// as one heading (label then value, read together), the body, the bottom
/// bar.
class AppPassPage extends StatefulWidget {
  const AppPassPage({
    required this.tone,
    required this.label,
    required this.value,
    this.tag,
    this.state,
    this.foot,
    this.isOn = true,
    this.slivers = const <Widget>[],
    this.trailing,
    this.bottomBar,
    this.onBack,
    this.backLabel,
    this.controller,
    super.key,
  });

  final PassTone tone;

  /// The pass label, in normal case. The header upper-cases it.
  final String label;

  /// The setting in full. It wraps and is never cut.
  final String value;

  /// The plan word, drawn only while the feature is locked and the plan is
  /// read.
  final String? tag;

  /// A word after the label and a dot, such as "playing". It is a live
  /// region: a screen reader announces a change once.
  final String? state;

  /// A mono line under the value, in the muted value colour.
  final String? foot;

  /// Whether the setting is on, which decides the value colour.
  final bool isOn;

  /// The body. They scroll under the pinned top row. The page adds no
  /// padding around them, so each sliver sets its own.
  final List<Widget> slivers;

  /// A control at the right of the top row, 44 points high, such as Play.
  final Widget? trailing;

  /// The page's one action, pinned under the scroll view.
  final Widget? bottomBar;

  /// What the back ring does. Defaults to popping the route.
  final VoidCallback? onBack;

  /// The back ring's spoken name. Defaults to "Back to Personalize" when the
  /// page grew out of a card and to "Back" otherwise.
  final String? backLabel;

  /// The scroll controller of the body, for a page that needs to scroll it.
  final ScrollController? controller;

  @override
  State<AppPassPage> createState() => _AppPassPageState();
}

class _AppPassPageState extends State<AppPassPage> {
  // One profile per ground: a new object on each build would ask the canvas
  // to retint on each frame of the transition.
  late AmbientProfile _profile = AmbientAppProfiles.passGround(
    widget.tone.ground,
  );

  bool _isClosing = false;

  @override
  void didUpdateWidget(covariant AppPassPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone.ground != widget.tone.ground) {
      _profile = AmbientAppProfiles.passGround(widget.tone.ground);
    }
  }

  /// While the page closes it lets go of the canvas, so the canvas turns back
  /// to the root's colour with the cards and not after them. If a drag is let
  /// go and the page stays, it takes the canvas again.
  void _followClosing(bool closing) {
    if (closing == _isClosing) return;
    _isClosing = closing;
    final controller = AmbientScope.controllerOf(context);
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isClosing != closing) return;
      if (closing) {
        controller.clearOverride();
      } else {
        controller.setOverride(profile: _profile);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = PassFrameScope.maybeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final columnWidth = math.min(width, AppSize.contentMaxWidth);
    final frame =
        scope?.frame ??
        PassFrame.settled(
          PassDisplay(MediaQuery.sizeOf(context), safeTop: padding.top),
        );
    final tone = widget.tone;
    final safeTop = padding.top;
    _followClosing(frame.isClosing);
    final backLabel =
        widget.backLabel ??
        (scope?.origin != null
            ? LocaleKeys.personalize_passes_page_back_label.tr()
            : LocaleKeys.personalize_passes_page_back_generic.tr());

    final scroll = CustomScrollView(
      controller: widget.controller,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: safeTop + kPassHeaderTop),
          sliver: SliverToBoxAdapter(
            child: Transform.translate(
              offset: frame.headerOffset,
              child: _HeaderBlock(
                tone: tone,
                label: widget.label,
                state: widget.state,
                tag: widget.tag,
                value: widget.value,
                valueSize: frame.valueSize,
                foot: widget.foot,
                isOn: widget.isOn,
              ),
            ),
          ),
        ),
        SliverOpacity(
          opacity: frame.bodyOpacity,
          sliver: SliverMainAxisGroup(slivers: widget.slivers),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: widget.bottomBar == null ? padding.bottom + 24 : 24,
          ),
        ),
      ],
    );

    final thumbnail = scope?.origin?.thumbnail;
    final stripHeight =
        safeTop + kPassRingTop + kPassRingSize + _kStripBelowRing;

    return AmbientOverride(
      profile: _profile,
      child: Material(
        color: tone.ground,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnail != null && frame.thumbOpacity > 0)
                    Positioned(
                      top: frame.rect.top + kPassThumbTop,
                      left:
                          frame.rect.right - kPassThumbRight - kPassThumbWidth,
                      width: kPassThumbWidth,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Opacity(
                            opacity: frame.thumbOpacity,
                            child: Transform.translate(
                              offset: frame.thumbOffset,
                              child: Transform.scale(
                                scale: frame.thumbScale,
                                alignment: Alignment.topRight,
                                child: thumbnail(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    sortKey: const OrdinalSortKey(1),
                    child: _Column(width: columnWidth, child: scroll),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Semantics(
                      sortKey: const OrdinalSortKey(0),
                      explicitChildNodes: true,
                      child: _TopRow(
                        tone: tone,
                        columnWidth: columnWidth,
                        stripHeight: stripHeight,
                        safeTop: safeTop,
                        ringOpacity: frame.ringOpacity,
                        backLabel: backLabel,
                        onBack:
                            widget.onBack ??
                            () => Navigator.of(context).maybePop(),
                        trailing: widget.trailing,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.bottomBar != null)
              Semantics(
                sortKey: const OrdinalSortKey(2),
                child: ColoredBox(
                  color: tone.ground,
                  child: SafeArea(
                    top: false,
                    child: Opacity(
                      opacity: frame.bodyOpacity,
                      child: _Column(
                        width: columnWidth,
                        child: widget.bottomBar!,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A child held in the centred column.
class _Column extends StatelessWidget {
  const _Column({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: width, child: child),
  );
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.tone,
    required this.label,
    required this.state,
    required this.tag,
    required this.value,
    required this.valueSize,
    required this.foot,
    required this.isOn,
  });

  final PassTone tone;
  final String label;
  final String? state;
  final String? tag;
  final String value;
  final double valueSize;
  final String? foot;
  final bool isOn;

  /// [valueSize], or less when the value's longest word would not fit the
  /// line, so a one word value never breaks inside the word.
  double _fittedSize(BuildContext context, double available) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final words = value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    double longestWord(double size) {
      var widest = 0.0;
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: passValueStyle(tone.onGround, size),
          ),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    return passFitValueSize(
      size: valueSize,
      available: available - 1,
      longestWord: longestWord,
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = PassLabelLine(
      label: label,
      state: state,
      tag: tag,
      color: tone.onGround,
    );
    final spoken = '${line.text}, $value${tag == null ? '' : ', $tag'}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPassSidePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            container: true,
            liveRegion: state != null,
            label: spoken,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line,
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final color = tone.valueFor(isOn: isOn);
                      final size = _fittedSize(context, constraints.maxWidth);
                      return Text(value, style: passValueStyle(color, size));
                    },
                  ),
                ),
              ],
            ),
          ),
          if (foot != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                foot!,
                style: AppTypography.mono(tone.valueMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.tone,
    required this.columnWidth,
    required this.stripHeight,
    required this.safeTop,
    required this.ringOpacity,
    required this.backLabel,
    required this.onBack,
    required this.trailing,
  });

  final PassTone tone;
  final double columnWidth;
  final double stripHeight;
  final double safeTop;
  final double ringOpacity;
  final String backLabel;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ground = tone.ground;
    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: stripHeight,
              width: double.infinity,
              child: ColoredBox(color: ground),
            ),
            IgnorePointer(
              child: SizedBox(
                height: _kStripEdge,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [ground, ground.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: safeTop + kPassRingTop,
          left: 0,
          right: 0,
          child: _Column(
            width: columnWidth,
            child: SizedBox(
              height: kPassRingSize,
              child: Stack(
                children: [
                  Positioned(
                    left: kPassRingLeft,
                    top: 0,
                    child: IgnorePointer(
                      ignoring: ringOpacity == 0,
                      child: Opacity(
                        opacity: ringOpacity,
                        child: PassBackRing(
                          color: tone.onGround,
                          label: backLabel,
                          onTap: onBack,
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Positioned(
                      right: kPassRingLeft,
                      top: 0,
                      height: kPassRingSize,
                      child: Opacity(
                        opacity: ringOpacity,
                        child: trailing,
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
