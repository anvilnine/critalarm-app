import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What a row in the inbox says about its topic.
enum AppInboxRowKind {
  /// Read, nothing wrong.
  normal,

  /// Has messages not read yet.
  unread,

  /// An alarm is ringing on this topic.
  ringing,

  /// An alarm was acknowledged and will ring again unless closed.
  acknowledged,

  /// The topic sent a warning.
  warning,

  /// An alarm rang and nobody answered.
  missed,

  /// An alarm was answered and closed a moment ago.
  handled,

  /// The topic is muted. The row dims and carries a crossed bell.
  muted,
}

/// True for the kinds that need the person: they sort first, read in bold and
/// wear a tint. A missed alarm needs them too but has no face.
bool inboxRowNeedsYou(AppInboxRowKind kind) => switch (kind) {
  AppInboxRowKind.ringing ||
  AppInboxRowKind.acknowledged ||
  AppInboxRowKind.warning ||
  AppInboxRowKind.missed ||
  AppInboxRowKind.handled => true,
  AppInboxRowKind.normal ||
  AppInboxRowKind.unread ||
  AppInboxRowKind.muted => false,
};

/// The 38 point face a row wears, or null. Only a topic that needs a look
/// has one: ringing, acknowledged, warning and handled.
FaceState? inboxRowFace(AppInboxRowKind kind) => switch (kind) {
  AppInboxRowKind.ringing => FaceState.alarmed,
  AppInboxRowKind.acknowledged => FaceState.acked,
  AppInboxRowKind.warning => FaceState.worried,
  AppInboxRowKind.handled => FaceState.happy,
  AppInboxRowKind.normal ||
  AppInboxRowKind.unread ||
  AppInboxRowKind.missed ||
  AppInboxRowKind.muted => null,
};

/// The fill behind a row, or null for a plain one. It is see-through for the
/// red and orange kinds, so it sits right on the white sheet and on the dark
/// one.
Color? inboxRowTint(AppInboxRowKind kind, AppColors colors) => switch (kind) {
  AppInboxRowKind.ringing => colors.crit.withValues(alpha: 0.18),
  AppInboxRowKind.warning => colors.high.withValues(alpha: 0.18),
  AppInboxRowKind.missed => colors.crit.withValues(alpha: 0.12),
  AppInboxRowKind.acknowledged => colors.cobaltTint,
  AppInboxRowKind.handled => colors.cream,
  AppInboxRowKind.normal ||
  AppInboxRowKind.unread ||
  AppInboxRowKind.muted => null,
};

/// The colour of the time cell. A kind that needs the person names its state
/// there in bold, in a deeper step of its own colour so it reads on its tint.
Color inboxRowTimeColor(AppInboxRowKind kind, AppColors colors) {
  Color deeper(Color base, double amount) =>
      Color.lerp(base, colors.ink, amount)!;
  return switch (kind) {
    AppInboxRowKind.ringing => colors.critText,
    AppInboxRowKind.missed => colors.critText,
    AppInboxRowKind.warning => deeper(colors.high, 0.45),
    AppInboxRowKind.acknowledged || AppInboxRowKind.handled => colors.ink,
    AppInboxRowKind.normal ||
    AppInboxRowKind.unread ||
    AppInboxRowKind.muted => colors.ink3,
  };
}

/// The text in the unread pill: the count, or `99+` past 99.
String inboxUnreadText(int count) => count > 99 ? '99+' : '$count';

/// The white sheet the inbox rows sit on: a 28 point radius, rows divided by a
/// hairline, no card per row.
class AppInboxSheet extends StatelessWidget {
  const AppInboxSheet({required this.children, super.key});

  /// Normally [AppInboxRow]s.
  final List<Widget> children;

  /// The sheet's corner radius.
  static const double radius = 28;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: isDark ? const [] : AppShadows.lightMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ColoredBox(
                    color: colors.hairline,
                    child: const SizedBox(height: 1),
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One topic in the inbox.
///
/// A bell before the mono name when the topic has Critical delivery, a pin and
/// a moon after it, the time at the right, the last message on two lines, an
/// unread pill, and a 38 point face for a topic that needs a look. The row
/// owns the look. The words come from the caller: [criticalLabel] and
/// [quietLabel] are what a screen reader says for the bell and the moon, and
/// the bell's words must come from the ring claim, never a fixed phrase.
///
/// Large text makes the row grow. The name keeps one line with an ellipsis and
/// the time drops under it. The face does not move.
class AppInboxRow extends StatefulWidget {
  const AppInboxRow({
    required this.name,
    required this.message,
    required this.time,
    this.kind = AppInboxRowKind.normal,
    this.unreadCount = 0,
    this.hasCriticalDelivery = false,
    this.criticalLabel,
    this.isPinned = false,
    this.isQuietHours = false,
    this.quietLabel,
    this.onTap,
    super.key,
  }) : assert(
         !hasCriticalDelivery || criticalLabel != null,
         'The bell needs words for a screen reader.',
       ),
       assert(
         !isQuietHours || quietLabel != null,
         'The moon needs words for a screen reader.',
       );

  /// The topic name, in mono. One line.
  final String name;

  /// The newest message, two lines at most.
  final String message;

  /// The time cell: a clock time, a day, or for a kind that needs the person
  /// the name of its state ("Ringing", "Nobody answered").
  final String time;

  final AppInboxRowKind kind;

  /// Messages not read yet. Zero draws no pill. Past 99 it reads `99+`.
  final int unreadCount;

  /// True draws a bell before the name.
  final bool hasCriticalDelivery;

  /// What a screen reader says for the bell.
  final String? criticalLabel;

  /// True draws a pin after the name.
  final bool isPinned;

  /// True draws a moon after the name: the phone's quiet hours are on.
  final bool isQuietHours;

  /// What a screen reader says for the moon.
  final String? quietLabel;

  final VoidCallback? onTap;

  @override
  State<AppInboxRow> createState() => _AppInboxRowState();
}

class _AppInboxRowState extends State<AppInboxRow> {
  bool _isPressed = false;

  /// The rows' scale while a finger is down.
  static const double pressScale = 0.985;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final kind = widget.kind;
    final needsYou = inboxRowNeedsYou(kind);
    final isUnread = kind == AppInboxRowKind.unread || widget.unreadCount > 0;
    final isMuted = kind == AppInboxRowKind.muted;
    final isStrong = needsYou || isUnread;
    final face = inboxRowFace(kind);
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final dropsTime = scale > kChromeMaxTextScale;

    final nameStyle = TextStyle(
      fontFamily: AppTypography.fontMono,
      fontFamilyFallback: AppTypography.fontMonoFallbacks,
      fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
      fontSize: 15,
      height: 1.3,
      color: colors.ink,
    );
    final timeStyle = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontWeight: needsYou ? FontWeight.w700 : FontWeight.w400,
      fontSize: 12.5,
      height: 1.3,
      color: inboxRowTimeColor(kind, colors),
    );
    final messageStyle = TextStyle(
      fontFamily: AppTypography.fontBody,
      fontFamilyFallback: AppTypography.fontBodyFallbacks,
      fontSize: 14,
      height: 1.35,
      color: isStrong ? colors.ink : colors.ink3,
    );

    final glyphColor = colors.ink3;
    final nameRow = Row(
      children: [
        if (widget.hasCriticalDelivery) ...[
          Semantics(
            label: widget.criticalLabel,
            child: AppGlyph(
              GlyphType.bell,
              color: colors.ink,
            ),
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        if (widget.isPinned) ...[
          const SizedBox(width: 6),
          AppGlyph(
            GlyphType.pin,
            size: 13,
            strokeWidth: 2.4,
            color: colors.ink,
          ),
        ],
        if (widget.isQuietHours) ...[
          const SizedBox(width: 6),
          AppGlyph(
            GlyphType.moon,
            size: 13,
            strokeWidth: 2.4,
            color: glyphColor,
          ),
        ],
        if (isMuted) ...[
          const SizedBox(width: 6),
          AppGlyph(
            GlyphType.bellOff,
            size: 13,
            strokeWidth: 2.4,
            color: glyphColor,
          ),
        ],
      ],
    );

    final timeText = Text(
      widget.time,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: timeStyle,
    );

    final header = dropsTime
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [nameRow, timeText],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: nameRow),
              const SizedBox(width: 8),
              Flexible(flex: 0, child: timeText),
            ],
          );

    final body = Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: messageStyle,
            ),
          ),
          if (widget.unreadCount > 0) ...[
            const SizedBox(width: 10),
            _InboxUnreadPill(count: widget.unreadCount),
          ],
        ],
      ),
    );

    final row = AnimatedScale(
      scale: _isPressed ? pressScale : 1,
      duration: context.motion(AppDurations.tap),
      curve: AppCurves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: inboxRowTint(kind, colors),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (face != null) ...[
                ExcludeSemantics(
                  child: FaceWidget(
                    state: face,
                    size: 38,
                    overrideFillColor: colors.yellow,
                    overrideStrokeColor: colors.inkFixed,
                    overrideInkColor: colors.inkFixed,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [header, body],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final spoken = [
      widget.name,
      if (widget.hasCriticalDelivery) widget.criticalLabel!,
      if (widget.isPinned) LocaleKeys.common_pinned.tr(),
      if (isMuted) LocaleKeys.common_muted.tr(),
      if (widget.isQuietHours) widget.quietLabel!,
      widget.time,
      if (widget.unreadCount > 0)
        LocaleKeys.home_unread_aria_label.tr(
          namedArgs: {'count': '${widget.unreadCount}'},
        ),
      widget.message,
    ].join(', ');

    return AnimatedOpacity(
      duration: context.motion(AppDurations.quick),
      opacity: isMuted ? 0.55 : 1,
      child: Semantics(
        button: widget.onTap != null,
        label: spoken,
        excludeSemantics: true,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap == null
                ? null
                : (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// The cobalt count at the right of a message: 22 points at least, `99+` past
/// 99.
class _InboxUnreadPill extends StatelessWidget {
  const _InboxUnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.highlight,
        borderRadius: Radii.fullAll,
      ),
      child: Text(
        inboxUnreadText(count),
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1,
          color: colors.onHighlight,
        ),
      ),
    );
  }
}
