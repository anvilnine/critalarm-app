import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_app_profiles.dart';
import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/pass_header_geometry.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// The back ring's size.
const double kPassRingSize = 44;

/// The ring's distance from the left edge of the column, and from the inset.
const double kPassRingLeft = 16;
const double kPassRingTop = 5;

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
/// 2. The body: [slivers], which scroll under the top bar. The page is an
///    [AppScreenScaffold], so the bar is backed the way every other screen's
///    is: the progressive blur and a fade of the ground colour, once a row is
///    under it.
/// 3. The top bar, holding the back ring at the left and the optional
///    [trailing] control at the right.
/// 4. The header: the label (with a [state] word and a [tag]) and the value.
///    It rests under the ring, and as the page scrolls it rises and moves right
///    until it sits beside the ring on the ring's centre line, where it stays.
///    The value steps down in size on the way. A page that does not scroll
///    keeps the resting header. See [passHeaderPoseAt].
/// 5. The optional [bottomBar], under the scroll view, on the ground colour.
///
/// Everything sits in a column `min(width, 560)` wide, centred; the ground
/// fills the display.
///
/// The page reads the route's [PassFrameScope]. While the page grows out of a
/// card, the header rides from the card's place to its own with the value
/// size, the ring and the body fade in, and the card's thumbnail flies behind
/// them. With no scope (the page opened without a card, or drawn on its own)
/// it is the finished page. The screen using it knows nothing of the
/// transition.
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

  /// The setting in full. It wraps and is never cut at rest. Collapsed into
  /// the bar it stays on one line and ends in an ellipsis when it is long.
  final String value;

  /// The plan word, drawn only while the feature is locked and the plan is
  /// read.
  final String? tag;

  /// A word after the label and a dot, such as "playing". It is a live
  /// region: a screen reader announces a change once.
  final String? state;

  /// A mono line under the value, in the muted value colour. It scrolls with
  /// the body.
  final String? foot;

  /// Whether the setting is on, which decides the value colour.
  final bool isOn;

  /// The body. They scroll under the top bar. The page adds no padding around
  /// them, so each sliver sets its own.
  final List<Widget> slivers;

  /// A control at the right of the top bar, 44 points high, such as Play. The
  /// collapsed header stops short of it.
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

  ScrollController? _own;

  /// How wide the trailing control came out, which the collapsed header keeps
  /// clear of.
  double _trailingWidth = 0;

  ScrollController get _scroll =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void didUpdateWidget(covariant AppPassPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone.ground != widget.tone.ground) {
      _profile = AmbientAppProfiles.passGround(widget.tone.ground);
    }
    if (widget.trailing == null && _trailingWidth != 0) _trailingWidth = 0;
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _setTrailingWidth(double width) {
    if (!mounted || (width - _trailingWidth).abs() < 0.5) return;
    setState(() => _trailingWidth = width);
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

  /// [size], or less when the value's longest word would not fit the line, so
  /// a one word value never breaks inside the word.
  double _fittedSize(double size, double available, double textScale) {
    final direction = Directionality.of(context);
    final words = widget.value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    double longestWord(double fontSize) {
      var widest = 0.0;
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: passValueStyle(widget.tone.onGround, fontSize),
          ),
          textDirection: direction,
          textScaler: TextScaler.linear(textScale),
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    return passFitValueSize(
      size: size,
      available: available - 1,
      longestWord: longestWord,
    );
  }

  /// The height the value takes at rest, wrapped to [width].
  double _valueHeight(double size, double width, double textScale) {
    final painter = TextPainter(
      text: TextSpan(
        text: widget.value,
        style: passValueStyle(widget.tone.onGround, size),
      ),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.linear(textScale),
    )..layout(maxWidth: math.max(0, width));
    final height = painter.height;
    painter.dispose();
    return height;
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

    // The header's resting size. The value is fitted to the line once, so the
    // header collapses from the size it is drawn at.
    final textScale = MediaQuery.textScalerOf(context).scale(100) / 100;
    final restWidth = columnWidth - 2 * kPassSidePadding;
    final restSize = _fittedSize(frame.valueSize, restWidth, textScale);
    final restValueHeight = _valueHeight(restSize, restWidth, textScale);
    final labelHeight = 11 * 1.2 * math.min(textScale, kChromeMaxTextScale);

    // The header is drawn over the body, so the body starts under it. The
    // scaffold's list starts under the bar, which is above the label.
    final headerRoom =
        kPassHeaderTop -
        AppScreenScaffold.topBarHeight +
        labelHeight +
        4 +
        restValueHeight;

    final slivers = <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: headerRoom)),
      if (widget.foot != null)
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: frame.headerOffset,
            // On the way out it goes with the body, so it is not left on the
            // part of the page that is still bigger than the card.
            child: Opacity(
              opacity: frame.isClosing ? frame.bodyOpacity : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  kPassSidePadding,
                  8,
                  kPassSidePadding,
                  0,
                ),
                child: Text(
                  widget.foot!,
                  style: AppTypography.mono(tone.valueMuted, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      SliverOpacity(
        opacity: frame.bodyOpacity,
        sliver: SliverMainAxisGroup(slivers: widget.slivers),
      ),
      // The page's closing space: the scaffold adds 16 and the inset (the
      // inset only when there is no bottom bar).
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];

    final topBar = Semantics(
      sortKey: const OrdinalSortKey(0),
      explicitChildNodes: true,
      child: _TopBar(
        tone: tone,
        ringOpacity: frame.ringOpacity,
        backLabel: backLabel,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
        trailing: widget.trailing,
        onTrailingWidth: _setTrailingWidth,
      ),
    );

    Widget scaffold = AppBarBackingScope(
      color: tone.ground,
      child: AppScreenScaffold(
        topBar: topBar,
        slivers: slivers,
        hasTabBar: false,
        withGhosts: false,
        withFades: false,
        backgroundColor: Colors.transparent,
        scrollController: _scroll,
        physics: ScrollConfiguration.of(context).getScrollPhysics(context),
        contentSortKey: const OrdinalSortKey(1),
      ),
    );
    // The bottom bar sits under the scroll view, which already stops above
    // it, so the scaffold has no inset of its own to leave.
    if (widget.bottomBar != null) {
      scaffold = MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: scaffold,
      );
    }

    final header = _Header(
      tone: tone,
      label: widget.label,
      fromLabel: scope?.origin?.label,
      state: widget.state,
      tag: widget.tag,
      value: widget.value,
      isOn: widget.isOn,
      scroll: _scroll,
      grow: frame.grow,
      shift: frame.headerOffset,
      width: columnWidth,
      left: (width - columnWidth) / 2,
      safeTop: safeTop,
      textScale: textScale,
      restSize: restSize,
      restValueHeight: restValueHeight,
      trailingWidth: widget.trailing == null ? 0 : _trailingWidth,
    );

    final thumbnail = scope?.origin?.thumbnail;

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
                  scaffold,
                  header,
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

/// The label and the value, over the body and the bar's backing. They follow
/// the scroll offset through [passHeaderPoseAt].
class _Header extends StatelessWidget {
  const _Header({
    required this.tone,
    required this.label,
    required this.fromLabel,
    required this.state,
    required this.tag,
    required this.value,
    required this.isOn,
    required this.scroll,
    required this.grow,
    required this.shift,
    required this.width,
    required this.left,
    required this.safeTop,
    required this.textScale,
    required this.restSize,
    required this.restValueHeight,
    required this.trailingWidth,
  });

  final PassTone tone;
  final String label;

  /// The label the card the page grows from shows, or null when the page did
  /// not grow from a card. While the page grows the header fades from this
  /// to [label], so a card that says "Look" does not flip to "Look for a
  /// topic" on the first frame.
  final String? fromLabel;
  final String? state;
  final String? tag;
  final String value;
  final bool isOn;
  final ScrollController scroll;

  /// 0 while the page is still the card and 1 once it is the page. The scroll
  /// offset counts by its cube, so a page closing from a scrolled place has
  /// its header back at rest early and lands in the card's header, inside the
  /// shrinking page the whole way.
  final double grow;

  /// How far the whole header sits from its resting place while the page grows
  /// out of a card.
  final Offset shift;

  /// The column's width and its left edge on the display.
  final double width;
  final double left;
  final double safeTop;
  final double textScale;
  final double restSize;
  final double restValueHeight;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final line = PassLabelLine(
      label: label,
      state: state,
      tag: tag,
      badge: tag == null
          ? null
          : passBadgeColorsFor(
              tone,
              yellow: context.appColors.yellow,
              inkFixed: context.appColors.inkFixed,
            ),
      color: tone.onGround,
      isSingleLine: true,
    );
    final spoken = '${line.text}, $value${tag == null ? '' : ', $tag'}';
    final from = fromLabel;
    // The cross-fade runs over the middle of the grow. A settled page
    // (grow 1) and a page with no card behind it draw its own label only.
    final labelMix = from == null || from == label
        ? 1.0
        : Curves.easeInOut.transform(((grow - 0.2) / 0.5).clamp(0.0, 1.0));
    final fromLine = labelMix >= 1
        ? null
        : PassLabelLine(label: from!, color: tone.onGround, isSingleLine: true);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: scroll,
          builder: (context, _) {
            final offset = scroll.hasClients
                ? math.max<double>(0, scroll.position.pixels)
                : 0.0;
            final pose = passHeaderPoseAt(
              offset: offset * grow * grow * grow,
              width: width,
              textScale: textScale,
              trailingWidth: trailingWidth,
              safeTop: safeTop,
              restValueSize: restSize,
              restValueHeight: restValueHeight,
            );
            final gap = pose.valueTop - pose.labelTop - pose.labelHeight;
            return Transform.translate(
              offset: shift,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: left + pose.labelLeft,
                    top: pose.labelTop,
                    width: pose.labelWidth,
                    child: Semantics(
                      sortKey: const OrdinalSortKey(0.5),
                      header: true,
                      container: true,
                      liveRegion: state != null,
                      label: spoken,
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (fromLine == null)
                            line
                          else
                            Stack(
                              children: [
                                Opacity(opacity: 1 - labelMix, child: fromLine),
                                Opacity(opacity: labelMix, child: line),
                              ],
                            ),
                          SizedBox(height: gap),
                          Text(
                            value,
                            maxLines: pose.valueMaxLines,
                            // An ellipsis with no line limit cuts the text to
                            // its first line.
                            overflow: pose.valueMaxLines == null
                                ? TextOverflow.clip
                                : TextOverflow.ellipsis,
                            textScaler: TextScaler.linear(pose.valueScale),
                            style: passValueStyle(
                              tone.valueFor(isOn: isOn),
                              pose.valueSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The back ring at the left of the top bar and the optional control at the
/// right. Both are 44 points high and sit 5 points under the inset.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.tone,
    required this.ringOpacity,
    required this.backLabel,
    required this.onBack,
    required this.trailing,
    required this.onTrailingWidth,
  });

  final PassTone tone;
  final double ringOpacity;
  final String backLabel;
  final VoidCallback onBack;
  final Widget? trailing;
  final ValueChanged<double> onTrailingWidth;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: kPassRingLeft,
        top: kPassRingTop,
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
          top: kPassRingTop,
          height: kPassRingSize,
          child: IgnorePointer(
            ignoring: ringOpacity == 0,
            child: Opacity(
              opacity: ringOpacity,
              child: _MeasureWidth(onWidth: onTrailingWidth, child: trailing!),
            ),
          ),
        ),
    ],
  );
}

/// Hands over how wide its child came out, once per change.
class _MeasureWidth extends SingleChildRenderObjectWidget {
  const _MeasureWidth({required this.onWidth, required Widget super.child});

  final ValueChanged<double> onWidth;

  @override
  _RenderMeasureWidth createRenderObject(BuildContext context) =>
      _RenderMeasureWidth(onWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureWidth renderObject,
  ) {
    renderObject.onWidth = onWidth;
  }
}

class _RenderMeasureWidth extends RenderProxyBox {
  _RenderMeasureWidth(this.onWidth);

  ValueChanged<double> onWidth;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size.width) return;
    _reported = size.width;
    // Handing the number over mid-layout would rebuild the page while it is
    // laying out, so wait for the frame to finish.
    final width = size.width;
    SchedulerBinding.instance.addPostFrameCallback((_) => onWidth(width));
  }
}
