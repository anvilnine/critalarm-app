import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One option in a strip on the Personalize page.
///
/// Every chip is the same height at every text size, so a strip never
/// changes height. At large text the label wraps to two lines. The picked
/// chip carries a tick and a solid outline, so it reads without colour. A
/// chip being tried carries a dashed outline and no tick, so the two are
/// never taken for each other.
class PersonalizeChip extends StatelessWidget {
  const PersonalizeChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.isMarked = false,
    this.trailing,
    this.picture,
    this.spokenLabel,
    super.key,
  });

  /// The height of every chip.
  static const double height = 48;

  final String label;
  final VoidCallback onTap;

  /// The saved choice: a tick and a solid outline.
  final bool isSelected;

  /// A dashed outline with no tick: the option being tried.
  final bool isMarked;

  /// A small picture before the label, for a chip whose label is one word.
  final Widget Function(Color color)? picture;

  /// What a screen reader says, where [label] is too short to stand alone.
  final String? spokenLabel;

  /// The widest a chip gets before its label wraps or is cut. The tick of
  /// the picked chip comes on top of it, so picking a chip never cuts its
  /// label.
  static const double maxWidth = 168;
  static const double _tickSize = 14;
  static const double _tickGap = 6;

  /// What the picked chip adds to its width: the tick, the gap after it,
  /// and its thicker outline on both sides.
  static const double _tickRoom = _tickSize + _tickGap + 2;

  /// A glyph after the label, for a chip that leaves the page.
  final GlyphType? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final isLarge = media.textScaler.scale(1) >= personalizeLargeText;
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      selected: isSelected,
      label: spokenLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          constraints: BoxConstraints(
            minWidth: 64,
            maxWidth: maxWidth + (isSelected ? _tickRoom : 0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundDecoration: isMarked && !isSelected
              ? DashedOutline(color: colors.ink, radius: radius)
              : null,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? colors.ink : colors.hairline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                AppGlyph(GlyphType.check, color: colors.ink),
                const SizedBox(width: _tickGap),
              ],
              if (picture != null) ...[
                picture!(colors.ink),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: MediaQuery(
                  // Two lines of this fit the chip up to here.
                  data: media.copyWith(
                    textScaler: media.textScaler.clamp(maxScaleFactor: 1.4),
                  ),
                  child: Text(
                    label,
                    maxLines: isLarge ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.small(
                      colors.ink,
                      fontSize: 13,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.15),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                AppGlyph(trailing!, size: 13, color: colors.ink3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of chips that scrolls sideways. Its height is fixed, with room
/// above the chips for a lock badge seated over a chip's edge.
class PersonalizeStrip extends StatelessWidget {
  const PersonalizeStrip({required this.children, super.key});

  final List<Widget> children;

  /// Room above the chips, for a badge seated over a chip's top edge.
  static const double badgeRoom = FeatureLock.badgeRoomAbove;

  /// How far a badge hangs past its option's end edge.
  static const double badgeOverhang = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PersonalizeChip.height + badgeRoom + Spacing.s1,
      // A strip holds a handful of chips, so all of them are built: a
      // screen reader can reach the ones off the edge.
      child: PersonalizeStripScroller(
        child: Row(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const SizedBox(width: Spacing.s2),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// How far in from an edge a strip's options fade out.
const double personalizeStripFade = 28;

/// Which edges of a strip fade: the ones with more options past them.
({bool start, bool end}) stripFadesFor({
  required double before,
  required double after,
}) => (start: before > 0.5, end: after > 0.5);

/// The sideways scroll of a strip. An edge with more options past it fades
/// out, so an option is never cut by a hard line and a badge is never
/// sliced in half. An edge with nothing past it stays sharp.
class PersonalizeStripScroller extends StatefulWidget {
  const PersonalizeStripScroller({required this.child, super.key});

  final Widget child;

  @override
  State<PersonalizeStripScroller> createState() =>
      _PersonalizeStripScrollerState();
}

class _PersonalizeStripScrollerState extends State<PersonalizeStripScroller> {
  final ScrollController _controller = ScrollController();
  ({bool start, bool end}) _fades = (start: false, end: false);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_readPosition);
  }

  /// The first layout sends no metrics notice, so the position is read
  /// once the frame that built this is done.
  void _readAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _readPosition());
  }

  void _readPosition() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.hasContentDimensions) _onMetrics(position);
  }

  bool _onMetrics(ScrollMetrics metrics) {
    final fades = stripFadesFor(
      before: metrics.extentBefore,
      after: metrics.extentAfter,
    );
    if (fades == _fades || !mounted) return false;
    void apply() {
      if (mounted && fades != _fades) setState(() => _fades = fades);
    }

    // A notice that arrives while the frame is being laid out waits for
    // the frame to end.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    _readAfterFrame();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final fadesLeft = isRtl ? _fades.end : _fades.start;
    final fadesRight = isRtl ? _fades.start : _fades.end;
    final scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: (note) => _onMetrics(note.metrics),
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          Spacing.s4,
          PersonalizeStrip.badgeRoom,
          Spacing.s4,
          Spacing.s1,
        ),
        child: widget.child,
      ),
    );
    if (!fadesLeft && !fadesRight) return scroller;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final run = (personalizeStripFade / bounds.width).clamp(0.0, 0.5);
        const clear = Color(0x00000000);
        const solid = Color(0xFF000000);
        return LinearGradient(
          colors: [
            if (fadesLeft) clear else solid,
            solid,
            solid,
            if (fadesRight) clear else solid,
          ],
          stops: [0, run, 1 - run, 1],
        ).createShader(bounds);
      },
      child: scroller,
    );
  }
}

/// A dashed outline in the shape of a rounded box: the mark of an option
/// that is being tried and is not saved.
class DashedOutline extends Decoration {
  const DashedOutline({
    required this.color,
    required this.radius,
    this.width = 2,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final BorderRadius radius;
  final double width;
  final double dash;
  final double gap;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedOutlinePainter(this);
}

class _DashedOutlinePainter extends BoxPainter {
  const _DashedOutlinePainter(this.outline);

  final DashedOutline outline;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = (offset & size).deflate(outline.width / 2);
    final shape = Path()..addRRect(outline.radius.toRRect(rect));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outline.width
      ..strokeCap = StrokeCap.round
      ..color = outline.color;
    for (final metric in shape.computeMetrics()) {
      // Whole dashes only, so the two ends of the line meet evenly.
      final count = (metric.length / (outline.dash + outline.gap)).floor();
      if (count <= 0) continue;
      final step = metric.length / count;
      final dash = step * outline.dash / (outline.dash + outline.gap);
      for (var i = 0; i < count; i++) {
        canvas.drawPath(
          metric.extractPath(i * step, i * step + dash),
          paint,
        );
      }
    }
  }
}
