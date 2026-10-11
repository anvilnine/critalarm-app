import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// What a bar takes out of its own padding for the icon buttons it holds.
///
/// An [AppIconButton] is a 40 circle in a 48 tap box, so the box reaches 4
/// past the circle on every side. The bar gives up the same 4 of its edge
/// padding on the side the button is on, and of the gap between the button
/// and the title, so the circle stays where it was. Above and below it
/// needs nothing: the scaffold hands the bar 58, and the bar's content is
/// centred on the line 34 from the top as it was in 56 with 12 above it (10
/// above it now).
({double top, double leading, double trailing}) _iconRoom(
  Widget? leading,
  Widget? trailing, {
  double? trailingRoom,
}) {
  final lead = leading is AppIconButton
      ? AppIconButton.tapRoom(leading.size)
      : 0.0;
  final trail =
      trailingRoom ??
      (trailing is AppIconButton ? AppIconButton.tapRoom(trailing.size) : 0.0);
  return (top: lead > trail ? lead : trail, leading: lead, trailing: trail);
}

/// [padding] after the bar has taken [room] out of it.
EdgeInsets _paddingAfter(
  BuildContext context,
  EdgeInsetsGeometry padding,
  ({double top, double leading, double trailing}) room, {
  required bool isSliver,
}) {
  double less(double value, double by) => value > by ? value - by : 0;
  final direction = Directionality.of(context);
  final resolved = padding.resolve(direction);
  final isRtl = direction == TextDirection.rtl;
  final start = less(isRtl ? resolved.right : resolved.left, room.leading);
  final end = less(isRtl ? resolved.left : resolved.right, room.trailing);
  return EdgeInsets.fromLTRB(
    isRtl ? end : start,
    // The sliver bar has no spare height, so its box takes the padding.
    isSliver ? less(resolved.top, room.top) : resolved.top,
    isRtl ? start : end,
    // The sliver bar centres its row between its top and bottom padding. The
    // other one has none below.
    isSliver ? less(resolved.bottom, room.top) : resolved.bottom,
  );
}

/// Top bar matching index.html .phone .bar.
/// Displays leading button (e.g. back), title text, spacer, and trailing widget (e.g. settings/action/chip).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 0),
    this.backgroundColor,
    this.trailingTapRoom,
    super.key,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  /// The room an [AppIconButton] buried in [trailing] adds around its circle
  /// (see [AppIconButton.tapRoom]), for a trailing widget that is not the
  /// button itself. Null reads it off [trailing] when that is the button.
  final double? trailingTapRoom;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final room = _iconRoom(leading, trailing, trailingRoom: trailingTapRoom);

    return Container(
      color: backgroundColor ?? Colors.transparent,
      padding: _paddingAfter(context, padding, room, isSliver: false),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            if (title != null || titleWidget != null)
              SizedBox(width: 12 - room.leading),
          ],
          if (titleWidget != null)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: titleWidget,
              ),
            )
          else if (title != null)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                // A heading, so VoiceOver's headings rotor can jump to it.
                child: Semantics(
                  header: true,
                  child: Text(
                    title!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.02 * 18,
                      color: colors.onCanvas,
                    ),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          if (trailing != null) ...[
            SizedBox(width: 8 - room.trailing),
            Flexible(
              flex: 0,
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sliver top bar matching AppTopBar for use in CustomScrollView.
class AppSliverTopBar extends StatelessWidget {
  const AppSliverTopBar({
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.backgroundColor,
    this.pinned = true,
    this.floating = false,
    this.collapsedHeight,
    this.expandedHeight,
    this.flexibleSpace,
    super.key,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool pinned;
  final bool floating;
  final double? collapsedHeight;
  final double? expandedHeight;
  final Widget? flexibleSpace;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = backgroundColor ?? Colors.transparent;
    final room = _iconRoom(leading, trailing);

    return SliverAppBar(
      pinned: pinned,
      floating: floating,
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      forceMaterialTransparency: true,
      automaticallyImplyLeading: false,
      collapsedHeight: collapsedHeight,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
      titleSpacing: 0,
      title: Padding(
        padding: _paddingAfter(context, padding, room, isSliver: true),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (leading != null) ...[
              leading!,
              if (title != null || titleWidget != null)
                SizedBox(width: 12 - room.leading),
            ],
            if (titleWidget != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: titleWidget,
                ),
              )
            else if (title != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.02 * 18,
                      color: colors.onCanvas,
                    ),
                  ),
                ),
              ),
            if (trailing != null) ...[
              SizedBox(width: 8 - room.trailing),
              // Loose fit, so a long trailing widget (the endpoint chip) gives
              // up width and ellipsises instead of overflowing the bar.
              Flexible(child: trailing!),
            ],
          ],
        ),
      ),
    );
  }
}
