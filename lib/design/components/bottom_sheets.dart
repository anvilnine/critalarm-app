import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A top-rounded surface card pinned to the bottom, with a drag handle.
///
/// When [scrollController] is set, the card's content is wrapped in a
/// [SingleChildScrollView] driven by it, so a [DraggableScrollableSheet] can
/// grow and shrink it.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.title,
    this.subtitle,
    this.scrollController,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: colors.hairline,
              borderRadius: Radii.fullAll,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontFamilyFallback: AppTypography.fontDisplayFallbacks,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02 * 19,
              color: colors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.small(colors.ink3, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
        ],
        child,
      ],
    );

    // The bottom safe area sits inside the content, not on the card, so the
    // last row scrolls with the list instead of meeting a hard edge above the
    // home indicator.
    final bottomPadding = 18 + bottomInset + viewInsets;

    final body = scrollController == null
        ? Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: content,
          )
        : SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: content,
          );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.xl),
          ),
          boxShadow: AppShadows.shadowLg(isDark: isDark),
        ),
        child: body,
      ),
    );
  }
}

/// One tappable row in an option sheet.
class AppSheetOption<T> {
  const AppSheetOption({
    required this.label,
    this.value,
    this.meta,
    this.glyph,
    this.isSelected = false,
    this.isDestructive = false,
  });

  final String label;
  final T? value;
  final String? meta;
  final GlyphType? glyph;
  final bool isSelected;
  final bool isDestructive;
}

/// The row an [AppSheetOption] becomes inside a sheet.
class AppSheetOptionRow<T> extends StatelessWidget {
  const AppSheetOptionRow({
    required this.option,
    required this.onTap,
    super.key,
  });

  final AppSheetOption<T> option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final labelColor = option.isDestructive ? colors.crit : colors.ink;
    final circleBorder = option.isSelected
        ? Border.all(color: colors.cobalt, width: 1.5)
        : Border.all(color: colors.hairline, width: 1.5);

    return Semantics(
      selected: option.isSelected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.isSelected ? colors.cobaltTint : colors.cream,
                    border: circleBorder,
                  ),
                  alignment: Alignment.center,
                  child: option.isSelected
                      ? AppGlyph(
                          GlyphType.check,
                          size: 13,
                          color: colors.cobalt,
                        )
                      : option.glyph != null
                      ? AppGlyph(
                          option.glyph!,
                          color: labelColor,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      if (option.meta != null)
                        Text(
                          option.meta!,
                          style: AppTypography.small(colors.ink3, fontSize: 12),
                        ),
                    ],
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

/// Shows an option sheet and resolves with the value of the option tapped, or
/// null if it is dismissed. Pass [content] instead of [options] for a custom
/// sheet (an input, for example); it receives the sheet's own context so its
/// buttons can pop it.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  String? title,
  String? subtitle,
  List<AppSheetOption<T>> options = const [],
  Widget Function(BuildContext sheetContext)? content,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      return AppBottomSheet(
        title: title,
        subtitle: subtitle,
        child: options.isNotEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    AppSheetOptionRow<T>(
                      option: option,
                      onTap: () => Navigator.of(sheetContext).pop(option.value),
                    ),
                ],
              )
            : content?.call(sheetContext) ?? const SizedBox.shrink(),
      );
    },
  );
}

/// Shows a sheet that starts partly open and drags up to full height. [content]
/// receives the sheet's own context so its buttons can pop it.
Future<T?> showExpandingSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext sheetContext) content,
  String? title,
  String? subtitle,
  double initialChildSize = 0.3,
  double minChildSize = 0.22,
  double maxChildSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          return AppBottomSheet(
            title: title,
            subtitle: subtitle,
            scrollController: scrollController,
            child: content(sheetContext),
          );
        },
      );
    },
  );
}
