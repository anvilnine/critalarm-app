import 'dart:async';

import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// One button revealed by swiping a row.
class AppSwipeAction {
  const AppSwipeAction({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final GlyphType glyph;
  final VoidCallback onPressed;

  /// Filled in the highlight colour. The rest sit on the quiet ash fill.
  final bool isPrimary;
}

/// Swipe a row sideways to reveal buttons behind it, the way Mail does.
///
/// [start] shows when the row is pulled right, [end] when it is pulled left.
/// Rows that share a [groupTag] close each other, so only one is ever open,
/// as long as the list sits inside a `SlidableAutoCloseBehavior`.
class AppSwipeActions extends StatelessWidget {
  const AppSwipeActions({
    required this.child,
    this.start = const [],
    this.end = const [],
    this.groupTag,
    super.key,
  });

  /// Each button's share of the row's width.
  static const double _extentPerAction = 0.22;

  final Widget child;
  final List<AppSwipeAction> start;
  final List<AppSwipeAction> end;
  final Object? groupTag;

  @override
  Widget build(BuildContext context) {
    // Clipped to the row, so the row slides away under its own edge instead
    // of out past the sheet it sits on.
    return ClipRRect(
      borderRadius: Radii.mdAll,
      child: Slidable(
        groupTag: groupTag,
        startActionPane: start.isEmpty ? null : _pane(start),
        endActionPane: end.isEmpty ? null : _pane(end),
        child: child,
      ),
    );
  }

  ActionPane _pane(List<AppSwipeAction> actions) => ActionPane(
    motion: const BehindMotion(),
    extentRatio: _extentPerAction * actions.length,
    children: [for (final a in actions) _ActionButton(action: a)],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final AppSwipeAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = action.isPrimary ? colors.highlight : colors.ash;
    final fg = action.isPrimary ? colors.onHighlight : colors.ink;

    return Expanded(
      child: Padding(
        // Matches the gap between rows, so a button reads as its own tile.
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          label: action.label,
          excludeSemantics: true,
          child: Material(
            color: bg,
            borderRadius: Radii.mdAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                AppHaptics.selection();
                action.onPressed();
                final slidable = Slidable.of(context);
                if (slidable != null) unawaited(slidable.close());
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppGlyph(action.glyph, size: 18, color: fg),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
