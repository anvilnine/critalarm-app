import 'package:critalarm/app/shell/app_ambient_shell.dart'
    show AppAmbientShell;
import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_transition.dart';
import 'package:flutter/widgets.dart';

/// Controller coordinating ambient canvas profile overrides from descendant
/// screens.
class AmbientController extends ChangeNotifier {
  AmbientProfile? _overrideProfile;
  AmbientDirection? _overrideDirection;

  AmbientProfile? get overrideProfile => _overrideProfile;
  AmbientDirection? get overrideDirection => _overrideDirection;

  void setOverride({
    required AmbientProfile? profile,
    AmbientDirection? direction,
  }) {
    if (_overrideProfile == profile && _overrideDirection == direction) {
      return;
    }
    _overrideProfile = profile;
    _overrideDirection = direction;
    notifyListeners();
  }

  void clearOverride() {
    if (_overrideProfile == null && _overrideDirection == null) return;
    _overrideProfile = null;
    _overrideDirection = null;
    notifyListeners();
  }
}

/// Inherited scope indicating that a persistent ambient canvas is active
/// behind this subtree, and providing access to the [AmbientController].
///
/// When active, screen scaffolds automatically default to transparent
/// backgrounds and omit decorative ghosts and canvas fades, letting the
/// ambient geometric shapes diffuse cleanly.
class AmbientScope extends InheritedWidget {
  const AmbientScope({
    required super.child,
    this.isActive = true,
    this.controller,
    super.key,
  });

  /// Whether the ambient canvas is actively rendered behind this scope.
  final bool isActive;

  /// The [AmbientController] coordinating profile overrides.
  final AmbientController? controller;

  /// Looks up the nearest [AmbientScope] up the widget tree.
  static AmbientScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AmbientScope>();
  }

  /// Looks up the nearest [AmbientController] up the widget tree.
  static AmbientController? controllerOf(BuildContext context) {
    return maybeOf(context)?.controller;
  }

  /// Whether the given context is located within an active ambient canvas
  /// scope.
  static bool isInAmbientScope(BuildContext context) {
    return maybeOf(context)?.isActive ?? false;
  }

  @override
  bool updateShouldNotify(covariant AmbientScope oldWidget) {
    return isActive != oldWidget.isActive || controller != oldWidget.controller;
  }
}

/// A widget that temporarily overrides the ambient background profile of the
/// surrounding [AppAmbientShell] while mounted.
class AmbientOverride extends StatefulWidget {
  const AmbientOverride({
    required this.profile,
    required this.child,
    this.direction,
    super.key,
  });

  final AmbientProfile profile;
  final AmbientDirection? direction;
  final Widget child;

  @override
  State<AmbientOverride> createState() => _AmbientOverrideState();
}

class _AmbientOverrideState extends State<AmbientOverride> {
  AmbientController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AmbientScope.controllerOf(context);
    if (_controller != controller) {
      _controller = controller;
      _applyOverride();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientOverride oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != oldWidget.profile ||
        widget.direction != oldWidget.direction) {
      _applyOverride();
    }
  }

  void _applyOverride() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      _controller?.setOverride(
        profile: widget.profile,
        direction: widget.direction,
      );
    });
  }

  @override
  void dispose() {
    _controller?.clearOverride();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
