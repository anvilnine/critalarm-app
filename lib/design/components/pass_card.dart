import 'dart:math' as math;

import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/components/pro_badge.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/design/tokens/pass_tones.dart'
    show PassBadgeColors, PassId, passBadgeColorsFor;

/// How far the value stops short of the thumbnail on a card.
const double _kThumbGap = 12;

/// The gap between the label and its plan badge.
const double _kTagGap = 10;

/// The plan badge on a label line: a compact pill with a lock and the plan
/// word.
///
/// It is as tall as the label's line, so it adds nothing to the line's
/// height and the header's geometry holds. The pill is a little taller than
/// that and is centred on it. It is not a button: it takes no tap and the
/// screen reader reads the plan from the card's own label.
class _PassTagBadge extends StatelessWidget {
  const _PassTagBadge({
    required this.word,
    required this.colors,
    required this.labelHeight,
  });

  final String word;
  final PassBadgeColors? colors;
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final colors = this.colors;
    return ExcludeSemantics(
      child: IntrinsicWidth(
        child: SizedBox(
          height: labelHeight * scale,
          child: OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            child: ProBadge(
              label: word,
              isLocked: true,
              isCompact: true,
              fill: colors?.fill,
              ink: colors?.ink,
              border: colors?.border,
            ),
          ),
        ),
      ),
    );
  }
}

/// A pass card's label line: the mono label, an optional state word after a
/// dot, and an optional tag.
///
/// The card and the page header draw it the same way, so the label that
/// slides to the header is the same text. The label is upper-cased here, so
/// `en.json` holds it as a normal word. It stops growing at the chrome text
/// limit, like the other chrome in the app.
class PassLabelLine extends StatelessWidget {
  const PassLabelLine({
    required this.label,
    required this.color,
    this.state,
    this.tag,
    this.badge,
    this.isSingleLine = false,
    super.key,
  });

  /// Keeps the label on one line and cuts it with an ellipsis, with the tag
  /// after it. The collapsed page header uses it.
  final bool isSingleLine;

  /// The pass label, such as "Wake-up challenge".
  final String label;

  /// A word after a dot, such as "playing". Pages only.
  final String? state;

  /// The plan word, drawn only while the feature is locked and the plan is
  /// read. The caller passes it from `planWordFor`.
  final String? tag;

  /// The colours of the tag's pill. Null draws the app's yellow pill.
  final PassBadgeColors? badge;

  /// Full text colour. Opacity would take the label under 4.5 to 1 on the
  /// standard look.
  final Color color;

  /// The text the label line shows, before it is upper-cased.
  String get text => state == null ? label : '$label · $state';

  @override
  Widget build(BuildContext context) {
    final capped = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: kChromeMaxTextScale);
    final labelText = Text(
      text.toUpperCase(),
      maxLines: isSingleLine ? 1 : null,
      overflow: isSingleLine ? TextOverflow.ellipsis : TextOverflow.clip,
      style: TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        height: 1.2,
        letterSpacing: 0.1 * 11,
        color: color,
      ),
    );
    final tagText = tag == null
        ? null
        : _PassTagBadge(word: tag!, colors: badge, labelHeight: 11 * 1.2);
    if (isSingleLine) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: capped),
        child: Row(
          children: [
            Flexible(child: labelText),
            if (tagText != null) ...[const SizedBox(width: _kTagGap), tagText],
          ],
        ),
      );
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: capped),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: _kTagGap,
        runSpacing: 2,
        children: [labelText, ?tagText],
      ),
    );
  }
}

/// The pill colours a pass of [tone] gets in the theme [colors] belong to.
PassBadgeColors _badgeColors(AppColors colors, PassTone tone) =>
    passBadgeColorsFor(tone, yellow: colors.yellow, inkFixed: colors.inkFixed);

/// The value's text style on a card and a page: Bricolage 800, tracked tight.
TextStyle passValueStyle(Color color, double size) => TextStyle(
  fontFamily: AppTypography.fontDisplay,
  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
  fontWeight: FontWeight.w800,
  fontSize: size,
  height: 1.05,
  letterSpacing: -0.03 * size,
  color: color,
);

/// The smallest size a value steps down to before one of its words breaks.
const double kPassValueMinSize = 30;

/// The size a value is drawn at so that its longest word fits on one line.
///
/// A value wraps between words and never inside one. When a single word is
/// wider than the [available] width at [size], the size steps down until the
/// word fits, and stops at [kPassValueMinSize]. Below that the word breaks,
/// which only a name with no spaces in it and a very large text size reach.
///
/// [longestWord] is the width of the widest word when drawn at the size it
/// is given. It is called a few times, because a text scaler need not be
/// linear.
double passFitValueSize({
  required double size,
  required double available,
  required double Function(double size) longestWord,
  double minSize = kPassValueMinSize,
}) {
  final floor = math.min(size, minSize);
  var fit = size;
  for (var pass = 0; pass < 4; pass++) {
    final width = longestWord(fit);
    if (width <= available || width <= 0) return fit;
    if (fit <= floor) return floor;
    // Width follows the size closely, so one step lands near the answer and
    // a second settles it. The small drop keeps rounding from tipping it over.
    fit = math.max(floor, fit * available / width - 0.1);
  }
  return fit;
}

/// How many lines of value a card in the overlapped stack draws.
///
/// Two, unless the [band] it shows (the distance to the next card's top) is
/// too short for a second line to clear the next card. Then one. A card with
/// no band, such as the last, draws two.
int passValueLinesFor({required double? band, required TextScaler textScaler}) {
  if (band == null) return 2;
  final label = 11 * math.min(textScaler.scale(1), kChromeMaxTextScale) * 1.2;
  final line = textScaler.scale(kPassCardValueSize) * 1.05;
  final room = band - kPassCardTopPadding - label - 4;
  return (room / line).floor().clamp(1, 2);
}

/// Tells the cards below whether the stack is laid out flat (text scale 1.3
/// and above): full radius, no cap on the value's lines, the thumbnail under
/// the value. `AppPassStack` places it.
class PassCardLayout extends InheritedWidget {
  const PassCardLayout({
    required this.isFlat,
    required super.child,
    super.key,
  });

  final bool isFlat;

  static bool isFlatOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PassCardLayout>()?.isFlat ??
      false;

  @override
  bool updateShouldNotify(PassCardLayout oldWidget) =>
      isFlat != oldWidget.isFlat;
}

/// Tells a card how much of it shows in the overlapped stack, because the next
/// card covers the rest. `AppPassStack` wraps every card but the last in one.
class PassCardBand extends InheritedWidget {
  const PassCardBand({
    required this.height,
    required super.child,
    super.key,
  });

  /// The distance from this card's top to the next card's top.
  final double height;

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PassCardBand>()?.height;

  @override
  bool updateShouldNotify(PassCardBand oldWidget) => height != oldWidget.height;
}

/// Marks the last card of a band stack (`AppPassBands`): it draws all four
/// corners round, because nothing is under it to cover them.
class PassCardEnd extends InheritedWidget {
  const PassCardEnd({required super.child, super.key});

  /// Whether the nearest [PassCardEnd] above [context] exists.
  static bool isEndOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PassCardEnd>() != null;

  @override
  bool updateShouldNotify(PassCardEnd oldWidget) => false;
}

/// One card of the Personalize stack.
///
/// A mono label, an optional tag, the current value in large type and a
/// thumbnail slot, on the pass's ground. Inside an `AppPassStack` it is
/// placed for you; alone it fills the box it is given.
///
/// - [onTap] gets the [PassOrigin] of this card, with its rect taken at the
///   tap. Push the page route with it as the go_router `extra`.
/// - A tap is a light selection haptic. The card scales to 0.985 while
///   pressed.
/// - While the card's page is up, a card inside a stack draws nothing (the
///   page stands in its place), and the other cards slide away with the
///   grow.
/// - The card is one node for a screen reader: a button labelled
///   `label, value` and, when [tag] is set, `, tag`. The thumbnail is left
///   out. Pass [semanticLabel] to say it another way and [semanticHint] for
///   what the tap opens.
class AppPassCard extends StatefulWidget {
  const AppPassCard({
    required this.pass,
    required this.tone,
    required this.label,
    required this.value,
    this.tag,
    this.thumbnail,
    this.isOn = true,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  });

  final PassId pass;

  /// Ground, text and value colours. The look pass computes its own.
  final PassTone tone;

  /// The mono caps line. Held in normal case and upper-cased by the card.
  final String label;

  /// The current setting, in full. Two lines in the overlapped stack and as
  /// many as it needs in the flat one, and always whole in the semantics.
  final String value;

  /// The plan word, or null. Pass it only while the feature is locked and the
  /// plan is read.
  final String? tag;

  /// The thumbnail, drawn 62 points wide at the top right. Null for none.
  final WidgetBuilder? thumbnail;

  /// Whether the setting is on, which decides the value colour. A challenge
  /// that is Off passes false.
  final bool isOn;

  /// What a tap does. Null makes the card inert.
  final ValueChanged<PassOrigin>? onTap;

  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<AppPassCard> createState() => _AppPassCardState();
}

class _AppPassCardState extends State<AppPassCard> {
  bool _isPressed = false;
  bool _isFocused = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  void _open() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    AppHaptics.selection();
    final box = context.findRenderObject()! as RenderBox;
    final isFlat = PassCardLayout.isFlatOf(context);
    final isRound = isFlat || PassCardEnd.isEndOf(context);
    onTap(
      PassOrigin(
        pass: widget.pass,
        rect: box.localToGlobal(Offset.zero) & box.size,
        tone: widget.tone,
        label: widget.label,
        value: widget.value,
        display: PassDisplay(
          MediaQuery.sizeOf(context),
          safeTop: MediaQuery.paddingOf(context).top,
        ),
        thumbnail: widget.thumbnail,
        bottomRadius: isRound ? kPassCardRadius : 0,
        visibleHeight: isFlat ? null : PassCardBand.maybeOf(context),
        reduceMotion: context.reduceMotion,
        handoff: PassOriginScope.maybeOf(context),
      ),
    );
  }

  String get _spokenLabel {
    final tag = widget.tag;
    final value = widget.value.isEmpty ? '' : ', ${widget.value}';
    return widget.semanticLabel ??
        '${widget.label}$value${tag == null ? '' : ', $tag'}';
  }

  /// The value's size on the card: [kPassCardValueSize], or less when the
  /// longest word would not fit [available].
  double _fittedValueSize(
    double available,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final words = widget.value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    double longestWord(double fontSize) {
      var widest = 0.0;
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: passValueStyle(widget.tone.onGround, fontSize),
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
      size: kPassCardValueSize,
      available: available - 1,
      longestWord: longestWord,
      minSize: 18,
    );
  }

  @override
  Widget build(BuildContext context) {
    final handoff = PassOriginScope.maybeOf(context);
    final card = _buildCard(context);
    if (handoff == null) return card;
    return ListenableBuilder(
      listenable: handoff,
      builder: (context, _) {
        final open = handoff.open;
        if (open == null) return card;
        if (open == widget.pass) {
          // The page stands where this card was. Under reduce motion the
          // card fades out first and the page fades in after it.
          final animation = handoff.animation;
          if (animation == null) return Opacity(opacity: 0, child: card);
          return AnimatedBuilder(
            animation: animation,
            child: card,
            builder: (context, child) => Opacity(
              opacity: handoff.frame?.openCardOpacity ?? 0,
              child: child,
            ),
          );
        }
        final isBelow = widget.pass.index > open.index;
        final animation = handoff.animation;
        if (animation == null) return card;
        return AnimatedBuilder(
          animation: animation,
          child: card,
          builder: (context, child) {
            final frame = handoff.frame;
            if (frame == null) return child!;
            return Transform.translate(
              offset: Offset(
                0,
                isBelow ? frame.othersOffset : frame.aboveOffset,
              ),
              child: Opacity(opacity: frame.othersOpacity, child: child),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    final colors = context.appColors;
    final tone = widget.tone;
    final isFlat = PassCardLayout.isFlatOf(context);
    final hasThumb = widget.thumbnail != null;
    final isRound = isFlat || PassCardEnd.isEndOf(context);
    final radius = isRound
        ? const BorderRadius.all(Radius.circular(kPassCardRadius))
        : const BorderRadius.vertical(top: Radius.circular(kPassCardRadius));

    final label = PassLabelLine(
      label: widget.label,
      tag: widget.tag,
      badge: widget.tag == null ? null : _badgeColors(colors, tone),
      color: tone.onGround,
      // In the overlapped stack the band is short and the thumbnail takes
      // the right side, so a long label is cut with an ellipsis and the
      // badge keeps its place after it. The flat stack has the room to wrap.
      isSingleLine: !isFlat,
    );
    final scaler = MediaQuery.textScalerOf(context);
    // An empty value draws nothing and keeps the height of one line, so the
    // card is as tall as a card with a value.
    final value = widget.value.isEmpty
        ? SizedBox(height: scaler.scale(kPassCardValueSize) * 1.05)
        : LayoutBuilder(
            builder: (context, box) {
              // A one word value steps down before it breaks inside the
              // word, as the page header does. Large text and a narrow
              // phone reach it.
              final size = _fittedValueSize(
                box.maxWidth,
                scaler,
                Directionality.of(context),
              );
              return Text(
                widget.value,
                maxLines: isFlat
                    ? null
                    : passValueLinesFor(
                        band: PassCardBand.maybeOf(context),
                        textScaler: scaler,
                      ),
                overflow: isFlat ? TextOverflow.clip : TextOverflow.ellipsis,
                style: passValueStyle(tone.valueFor(isOn: widget.isOn), size),
              );
            },
          );
    final thumb = hasThumb
        // A thumbnail is a picture: it keeps its size at any text scale.
        ? MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: SizedBox(
              width: kPassThumbWidth,
              child: widget.thumbnail!(context),
            ),
          )
        : null;

    final Widget content;
    if (isFlat) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(
          kPassSidePadding,
          kPassCardTopPadding,
          kPassSidePadding,
          kPassCardTopPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            const SizedBox(height: 4),
            value,
            if (thumb != null) ...[const SizedBox(height: 12), thumb],
          ],
        ),
      );
    } else {
      final rightPadding = hasThumb
          ? kPassThumbRight + kPassThumbWidth + _kThumbGap
          : kPassSidePadding;
      content = Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              kPassSidePadding,
              kPassCardTopPadding,
              rightPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 4), value],
            ),
          ),
          if (thumb != null)
            Positioned(
              top: kPassThumbTop,
              right: kPassThumbRight,
              child: thumb,
            ),
        ],
      );
    }

    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: tone.ground,
        borderRadius: radius,
        boxShadow: isFlat
            ? null
            : [
                BoxShadow(
                  color: colors.inkFixed.withValues(alpha: 0.18),
                  offset: const Offset(0, -8),
                  blurRadius: 20,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          foregroundPainter: _TopEdgePainter(tone.edge),
          child: SizedBox(width: double.infinity, child: content),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      label: _spokenLabel,
      hint: widget.semanticHint,
      onTap: _enabled ? _open : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowFocusHighlight: (value) => setState(() => _isFocused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: _enabled ? _open : null,
          child: AnimatedScale(
            scale: _isPressed ? 0.985 : 1,
            duration: context.motion(AppDurations.tap),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                face,
                if (_isFocused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: tone.onGround, width: 3),
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

/// The 1 point line along a card's top edge, following its rounded corners.
class _TopEdgePainter extends CustomPainter {
  const _TopEdgePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const r = kPassCardRadius - 0.5;
    final path = Path()
      ..moveTo(0.5, kPassCardRadius)
      ..arcToPoint(
        const Offset(kPassCardRadius, 0.5),
        radius: const Radius.circular(r),
      )
      ..lineTo(size.width - kPassCardRadius, 0.5)
      ..arcToPoint(
        Offset(size.width - 0.5, kPassCardRadius),
        radius: const Radius.circular(r),
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TopEdgePainter oldDelegate) => oldDelegate.color != color;
}
