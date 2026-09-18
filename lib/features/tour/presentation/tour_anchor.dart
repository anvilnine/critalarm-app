import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as a spot the tour can point at.
///
/// A GlobalKey would crash here: the tab branches stay alive side by side, so
/// the same screen can be built twice at once (a topic open under Topics and
/// another under History). Anchors register instead, and the tour picks the
/// one that is actually on the display.
class TourAnchor extends StatefulWidget {
  const TourAnchor({required this.id, required this.child, super.key});

  final TourAnchorId id;
  final Widget child;

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  @override
  void initState() {
    super.initState();
    TourAnchors.add(widget.id, context);
  }

  @override
  void didUpdateWidget(TourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    TourAnchors.remove(oldWidget.id, context);
    TourAnchors.add(widget.id, context);
  }

  @override
  void dispose() {
    TourAnchors.remove(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Where every mounted [TourAnchor] is.
abstract final class TourAnchors {
  static final Map<TourAnchorId, List<BuildContext>> _byId = {};

  static void add(TourAnchorId id, BuildContext context) =>
      (_byId[id] ??= []).add(context);

  static void remove(TourAnchorId id, BuildContext context) =>
      _byId[id]?.remove(context);

  /// The anchor for [id] the user can see right now, or null.
  ///
  /// Skipped: anything in a tab that is not showing (its tickers are off), and
  /// anything on a page with another page on top of it.
  static BuildContext? visible(TourAnchorId id) {
    for (final context in _byId[id] ?? const <BuildContext>[]) {
      if (!context.mounted) continue;
      if (!TickerMode.valuesOf(context).enabled) continue;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) continue;
      final box = context.findRenderObject();
      // Zero size is a widget with nothing in it yet, such as the search
      // panel before its results come in.
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty) continue;
      return context;
    }
    return null;
  }
}
