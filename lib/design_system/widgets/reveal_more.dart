import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/design_system/tokens/durations.dart';
import 'package:critalarm/design_system/tokens/spacing.dart';
import 'package:flutter/material.dart';

/// A "SHOW ALL (N) / SHOW LESS" toggle over a stack of on-demand rows. Used
/// where hidden data must stay reachable, never lost (scan detail, compare).
///
/// Deliberately plain: a text button over an [AnimatedSize] reveal, no blur
/// and no glow.
/// The caller passes already-uppercased labels.
class RevealMore extends StatefulWidget {
  const RevealMore({
    required this.expandLabel,
    required this.collapseLabel,
    required this.children,
    super.key,
  });

  /// Collapsed-state label, e.g. "SHOW ALL (3)".
  final String expandLabel;

  /// Expanded-state label, e.g. "SHOW LESS".
  final String collapseLabel;

  /// The rows revealed when expanded.
  final List<Widget> children;

  @override
  State<RevealMore> createState() => _RevealMoreState();
}

class _RevealMoreState extends State<RevealMore> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: context.motion(AppDurations.enter),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                )
              : const SizedBox(width: double.infinity),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? widget.collapseLabel : widget.expandLabel,
            ),
          ),
        ),
        const SizedBox(height: Spacing.xxs),
      ],
    );
  }
}
