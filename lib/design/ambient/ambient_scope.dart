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
  final Map<String, AmbientProfile> _routeProfiles = <String, AmbientProfile>{};

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

  /// The profile a screen has registered for the route at [path], or null.
  AmbientProfile? routeProfileFor(String path) => _routeProfiles[path];

  /// Registers [profile] as the backdrop for the route at [path], in place of
  /// the shell's own choice for it.
  ///
  /// Unlike an override, it belongs to the route and not to the moment: it
  /// is used whenever the router shows [path] and left alone while it shows
  /// anything else, so a tab that stays alive behind another one keeps it.
  void setRouteProfile(String path, AmbientProfile profile) {
    if (_routeProfiles[path] == profile) return;
    _routeProfiles[path] = profile;
    notifyListeners();
  }

  /// Takes back what [setRouteProfile] registered for [path].
  void clearRouteProfile(String path) {
    if (_routeProfiles.remove(path) == null) return;
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

/// Registers the backdrop of the route at [path] with the surrounding
/// [AppAmbientShell] while mounted, and keeps it up to date as [profile]
/// changes.
///
/// This is how a screen that stays alive under a tab bar (the Topics tab)
/// picks its backdrop and changes it with its own state. The canvas lerps
/// from the old profile to the new one, so a change of state is a morph, and
/// a tab change or a push still moves the canvas to the next route's profile.
/// An [AmbientOverride] is for a screen that owns the whole display for a
/// while. It is dropped on every route change, and this is not.
class AmbientRouteProfile extends StatefulWidget {
  const AmbientRouteProfile({
    required this.path,
    required this.profile,
    required this.child,
    super.key,
  });

  /// The router path the profile is for, for example `/`.
  final String path;

  final AmbientProfile profile;
  final Widget child;

  @override
  State<AmbientRouteProfile> createState() => _AmbientRouteProfileState();
}

class _AmbientRouteProfileState extends State<AmbientRouteProfile> {
  AmbientController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AmbientScope.controllerOf(context);
    if (_controller != controller) {
      _controller?.clearRouteProfile(widget.path);
      _controller = controller;
      _apply();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientRouteProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _controller?.clearRouteProfile(oldWidget.path);
      _apply();
    } else if (widget.profile != oldWidget.profile) {
      _apply();
    }
  }

  /// Registers after the frame: the shell rebuilds on a change, and a build
  /// cannot ask another widget to rebuild.
  void _apply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The newest profile, not the one this callback was queued with.
      _controller?.setRouteProfile(widget.path, widget.profile);
    });
  }

  @override
  void dispose() {
    _controller?.clearRouteProfile(widget.path);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
