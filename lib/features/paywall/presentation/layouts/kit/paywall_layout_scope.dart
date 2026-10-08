import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What this paywall sells and to whom: the part of the scope that is known
/// before anything is laid out.
///
/// The frame hands these to its builder inside a `PaywallLayoutScope`. A
/// layout that also draws outside `PaywallFrameBody` reads them here, so
/// both parts list the same benefits.
@immutable
class PaywallOffer {
  const PaywallOffer({
    required this.product,
    required this.benefits,
    required this.source,
  });

  /// The offer of the paywall route above [context].
  factory PaywallOffer.of(BuildContext context) {
    final info = PaywallRouteInfo.maybeOf(context);
    final product = BlocProvider.of<PaywallBuyCubit>(context).state.product;
    return PaywallOffer(
      product: product,
      benefits: info?.showsUnbuilt ?? false
          ? [
              for (final b in allPaywallBenefits)
                if (b.product == product) b,
            ]
          : paywallBenefitsFor(product),
      source: info?.source ?? PaywallSource.direct,
    );
  }

  final PaywallProduct product;

  /// What to list, in display order. Only benefits this build has.
  final List<PaywallBenefit> benefits;

  /// What opened the paywall.
  final PaywallSource source;

  bool get isHosted => product == PaywallProduct.hosted;
  bool get isPro => product == PaywallProduct.pro;
}

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
    required this.close,
    this.intro = PaywallIntroId.none,
  });

  /// Edge of the square the close cross takes in a top corner of the
  /// layout's area. Keep words and taps out of that corner.
  static const double closeCrossSize = 44;

  /// How far that square sits in from the side edge of the layout's area.
  /// It touches the top edge.
  static const double closeCrossInset = Spacing.s1;

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

  /// Closes the paywall, as a tap on the cross does.
  final VoidCallback close;

  /// The intro that plays before this layout on this open. `none` when
  /// there is none, and when nothing may move, since an intro is then
  /// skipped. The layout's clock starts at zero as the intro hands over.
  final PaywallIntroId intro;

  /// True when the layout comes in under the end of an intro, which ends
  /// on the mascot. A layout may then shorten or skip its own entrance pop.
  bool get followsIntro => intro != PaywallIntroId.none;

  bool get isHosted => product == PaywallProduct.hosted;
  bool get isPro => product == PaywallProduct.pro;

  /// The scope of the frame above [context], for a widget deep inside a
  /// layout.
  static PaywallLayoutScope of(BuildContext context) => maybeOf(context)!;

  /// The same, or null where no frame is above: a preview in the gallery.
  static PaywallLayoutScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PaywallLayoutScopeProvider>()
      ?.scope;
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
      scope.intro != oldWidget.scope.intro ||
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

/// No cue and no haptic from anything below it. A thumbnail that plays a
/// layout puts one above it, so opening a picker makes no sound.
class PaywallMuted extends InheritedWidget {
  const PaywallMuted({required super.child, super.key});

  /// Whether what is under [context] stays silent. Safe in `initState`.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PaywallMuted>() != null;

  @override
  bool updateShouldNotify(PaywallMuted oldWidget) => false;
}

/// What the step after a purchase tells the layout under it.
class PaywallThanksHandle {
  /// True from the frame the product is known to be held: the step after
  /// the purchase has the screen and the sound from then on, so the layout
  /// under it plays no cue of its own.
  bool hasBegun = false;
}

/// Says that something of its own plays after a purchase on the layout
/// below. `PaywallThanksHost` puts it there, and only when a version is
/// set and built.
///
/// The buy block reads it: with one above, the block does not change to
/// its own done state when the purchase is confirmed, so nothing under the
/// show moves as it starts.
class PaywallThanksPlay extends InheritedWidget {
  const PaywallThanksPlay({
    required this.handle,
    required super.child,
    super.key,
  });

  final PaywallThanksHandle handle;

  /// Whether a step after the purchase takes over from the buy block
  /// under [context].
  static bool takesOver(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaywallThanksPlay>() != null;

  /// Whether that step has begun. It does not listen, so it is safe on a
  /// tick.
  static bool hasBegun(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<PaywallThanksPlay>()
          ?.handle
          .hasBegun ??
      false;

  @override
  bool updateShouldNotify(PaywallThanksPlay oldWidget) => false;
}
