import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Top bar matching index.html .phone .bar.
/// Displays leading button (e.g. back), title text, spacer, and trailing widget (e.g. settings/action/chip).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    this.backgroundColor,
    super.key,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      color: backgroundColor ?? Colors.transparent,
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            if (title != null || titleWidget != null) const SizedBox(width: 12),
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
            )
          else
            const Spacer(),
          if (trailing != null) ...[
            const SizedBox(width: 8),
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
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              if (title != null || titleWidget != null)
                const SizedBox(width: 12),
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
              )
            else
              const Spacer(),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
