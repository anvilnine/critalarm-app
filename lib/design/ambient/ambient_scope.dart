import 'package:flutter/widgets.dart';

/// Inherited scope indicating that a persistent ambient canvas is active
/// behind this subtree.
///
/// When active, screen scaffolds automatically default to transparent
/// backgrounds and omit decorative ghosts and canvas fades, letting the
/// ambient geometric shapes diffuse cleanly.
class AmbientScope extends InheritedWidget {
  const AmbientScope({
    required super.child,
    this.isActive = true,
    super.key,
  });

  /// Whether the ambient canvas is actively rendered behind this scope.
  final bool isActive;

  /// Looks up the nearest [AmbientScope] up the widget tree.
  static AmbientScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AmbientScope>();
  }

  /// Whether the given context is located within an active ambient canvas
  /// scope.
  static bool isInAmbientScope(BuildContext context) {
    return maybeOf(context)?.isActive ?? false;
  }

  @override
  bool updateShouldNotify(covariant AmbientScope oldWidget) {
    return isActive != oldWidget.isActive;
  }
}
