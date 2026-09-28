import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as a spot the guide can point at.
///
/// A GlobalKey would crash here: the tab branches stay alive side by side, so
/// the same screen can be built twice at once (a topic open under Topics and
/// another under History). Anchors register instead, and the guide picks the
/// one that is actually on the display.
class FeatureGuideAnchor extends StatefulWidget {
  const FeatureGuideAnchor({required this.id, required this.child, super.key});

  final FeatureGuideAnchorId id;
  final Widget child;

  @override
  State<FeatureGuideAnchor> createState() => _FeatureGuideAnchorState();
}

class _FeatureGuideAnchorState extends State<FeatureGuideAnchor> {
  @override
  void initState() {
    super.initState();
    FeatureGuideAnchors.add(widget.id, context);
  }

  @override
  void didUpdateWidget(FeatureGuideAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    FeatureGuideAnchors.remove(oldWidget.id, context);
    FeatureGuideAnchors.add(widget.id, context);
  }

  @override
  void dispose() {
    FeatureGuideAnchors.remove(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Where every mounted [FeatureGuideAnchor] is.
abstract final class FeatureGuideAnchors {
  static final Map<FeatureGuideAnchorId, List<BuildContext>> _byId = {};

  static void add(FeatureGuideAnchorId id, BuildContext context) =>
      (_byId[id] ??= []).add(context);

  static void remove(FeatureGuideAnchorId id, BuildContext context) =>
      _byId[id]?.remove(context);

  /// The anchor for [id] the user can see right now, or null.
  ///
  /// Skipped: anything in a tab that is not showing (its tickers are off), and
  /// anything on a page with another page on top of it.
  static BuildContext? visible(FeatureGuideAnchorId id) {
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
