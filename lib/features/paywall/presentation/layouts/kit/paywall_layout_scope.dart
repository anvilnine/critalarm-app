import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/widgets.dart';

/// What the frame hands a layout to draw with.
@immutable
class PaywallLayoutScope {
  const PaywallLayoutScope({
    required this.product,
    required this.benefits,
    required this.size,
    required this.isCompact,
    required this.source,
    required this.clock,
    required this.closeOnLeft,
  });

  /// Edge of the square the close cross takes in a top corner of the
  /// layout's area. Keep words and taps out of that corner.
  static const double closeCrossSize = 44;

  /// A phone this tall or shorter is compact.
  static const double compactHeight = 667;

  final PaywallProduct product;

  /// What to list, in display order. Only benefits this build has.
  final List<PaywallBenefit> benefits;

  /// The room the layout has: the screen less the safe areas and the buy
  /// block. The close cross sits over its top corner.
  final Size size;

  /// True on a phone 667 points tall or shorter.
  final bool isCompact;

  /// What opened the paywall.
  final PaywallSource source;

  /// Seconds since the layout appeared. See `PaywallClockBuilder`.
  final PaywallClock clock;

  /// Which top corner holds the close cross.
  final bool closeOnLeft;

  bool get isHosted => product == PaywallProduct.hosted;
  bool get isPro => product == PaywallProduct.pro;

  /// The scope of the frame above [context], for a widget deep inside a
  /// layout.
  static PaywallLayoutScope of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PaywallLayoutScopeProvider>()!
      .scope;
}

/// Carries the scope down a layout's tree. The frame puts it there.
class PaywallLayoutScopeProvider extends InheritedWidget {
  const PaywallLayoutScopeProvider({
    required this.scope,
    required super.child,
    super.key,
  });

  final PaywallLayoutScope scope;

  @override
  bool updateShouldNotify(PaywallLayoutScopeProvider oldWidget) =>
      scope.product != oldWidget.scope.product ||
      scope.size != oldWidget.scope.size ||
      scope.isCompact != oldWidget.scope.isCompact ||
      scope.source != oldWidget.scope.source ||
      scope.closeOnLeft != oldWidget.scope.closeOnLeft ||
      scope.benefits.length != oldWidget.scope.benefits.length;
}

/// What the route knows about this paywall. `PaywallLayoutScreen` puts it
/// above the layout and the frame reads it.
class PaywallRouteInfo extends InheritedWidget {
  const PaywallRouteInfo({
    required this.layout,
    required this.source,
    required super.child,
    this.showsUnbuilt = false,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallSource source;

  /// A developer view that also lists the benefits this build does not
  /// have yet, to see a layout with the full list.
  final bool showsUnbuilt;

  static PaywallRouteInfo? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaywallRouteInfo>();

  @override
  bool updateShouldNotify(PaywallRouteInfo oldWidget) =>
      layout != oldWidget.layout ||
      source != oldWidget.source ||
      showsUnbuilt != oldWidget.showsUnbuilt;
}
