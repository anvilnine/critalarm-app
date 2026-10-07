import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

export 'package:critalarm/core/ui_sound/paywall_cues.dart'
    show PaywallEntranceCue;
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';

/// Draws a layout's own part in the room the frame has left.
typedef PaywallLayoutContentBuilder =
    Widget Function(BuildContext context, PaywallLayoutScope scope);

/// The text scale a layout's own part stops growing at. A one screen
/// composition cannot hold text of any size, so past this only the legal
/// lines keep growing, inside their own box.
const double paywallLayoutMaxTextScale = 1.5;

/// The one-screen scaffold of every paywall layout. It never scrolls.
///
/// It paints the tone, keeps the safe areas, puts the close cross on screen
/// from the first frame and pins the buy block at the bottom. The layout
/// draws in what is left, through [builder].
class PaywallFrame extends StatelessWidget {
  const PaywallFrame({
    required this.builder,
    this.tone = PaywallTone.canvas,
    this.closeOnLeft = true,
    this.buyBlockVisible = true,
    this.entranceCue = PaywallEntranceCue.open,
    this.restAt = 0,
    this.buyStyle,
    this.backdrop,
    super.key,
  });

  final PaywallLayoutContentBuilder builder;

  /// The background, and with it the colour of the close cross and of the
  /// buy block's text.
  final PaywallTone tone;
  final bool closeOnLeft;

  /// False hides the buy block, for an entrance that plays first. The block
  /// keeps its room, so the layout does not move when it comes in, and the
  /// close cross stays.
  final bool buyBlockVisible;

  /// The cue played once when the layout appears.
  final PaywallEntranceCue entranceCue;

  /// The second the scope's clock rests on when nothing may move.
  final double restAt;

  /// How the buy block is drawn. Null takes the defaults for [tone].
  final PaywallBuyBlockStyle? buyStyle;

  /// Drawn edge to edge behind everything, under the status bar and the
  /// buy block. For a layout whose background is more than one tone.
  final Widget? backdrop;

  /// Whether the phone under [context] is compact. For a choice the frame
  /// needs before its builder runs, such as the picker style.
  static bool isCompactOf(BuildContext context) =>
      MediaQuery.sizeOf(context).height <= PaywallLayoutScope.compactHeight;

  @override
  Widget build(BuildContext context) {
    final background = PaywallToneColors.of(context, tone).background;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDarkBackground
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ?backdrop,
            SafeArea(
              // The links row ends in blank tap area, so it may reach a
              // little into the home indicator's inset.
              bottom: false,
              minimum: EdgeInsets.only(
                bottom: math.max(
                  0,
                  MediaQuery.viewPaddingOf(context).bottom - Spacing.s3,
                ),
              ),
              child: PaywallFrameBody(
                builder: builder,
                tone: tone,
                closeOnLeft: closeOnLeft,
                buyBlockVisible: buyBlockVisible,
                entranceCue: entranceCue,
                restAt: restAt,
                buyStyle: buyStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The frame's content without the full screen: the layout's part, the
/// close cross and the buy block. A sheet-style layout puts this inside its
/// own sheet, with a bounded height.
class PaywallFrameBody extends StatefulWidget {
  const PaywallFrameBody({
    required this.builder,
    this.tone = PaywallTone.canvas,
    this.closeOnLeft = true,
    this.buyBlockVisible = true,
    this.entranceCue = PaywallEntranceCue.open,
    this.restAt = 0,
    this.buyStyle,
    super.key,
  });

  final PaywallLayoutContentBuilder builder;
  final PaywallTone tone;
  final bool closeOnLeft;
  final bool buyBlockVisible;
  final PaywallEntranceCue entranceCue;
  final double restAt;
  final PaywallBuyBlockStyle? buyStyle;

  @override
  State<PaywallFrameBody> createState() => _PaywallFrameBodyState();
}

class _PaywallFrameBodyState extends PaywallClockState<PaywallFrameBody> {
  late final _FrameClock _clock = _FrameClock(
    read: () => t,
    readIsStill: () => isStill,
    onRestart: restart,
  );
  late final PaywallCues _cues;
  late final PaywallBuyCubit _buy;

  /// True once the close cue played, so leaving plays it once.
  bool _saidClose = false;

  @override
  double get restAt => widget.restAt;

  // The frame does not redraw on a tick. Only what listens to the clock
  // does.
  @override
  void onTick() => _clock.tell();

  @override
  void initState() {
    super.initState();
    _cues = getIt<PaywallCues>();
    _buy = context.read<PaywallBuyCubit>();
    switch (widget.entranceCue) {
      case PaywallEntranceCue.open:
        _cues.open();
      case PaywallEntranceCue.gag:
        _cues.gag();
      case PaywallEntranceCue.print:
        _cues.print();
      case PaywallEntranceCue.none:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stillness may have changed, and with it what the clock reads.
    _clock.tell();
  }

  void _sayClose() {
    if (_saidClose) return;
    _saidClose = true;
    // Leaving with the product in hand is not a dismissal.
    if (_buy.state.status != PaywallBuyStatus.done) _cues.close();
  }

  void _close() {
    _sayClose();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    // Back and a swipe leave without the cross.
    _sayClose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = PaywallToneColors.of(context, widget.tone);
    final info = PaywallRouteInfo.maybeOf(context);
    final product = _buy.state.product;
    final benefits = info?.showsUnbuilt ?? false
        ? [
            for (final b in allPaywallBenefits)
              if (b.product == product) b,
          ]
        : paywallBenefitsFor(product);
    final isCompact = PaywallFrame.isCompactOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scope = PaywallLayoutScope(
                      product: product,
                      benefits: benefits,
                      size: constraints.biggest,
                      isCompact: isCompact,
                      source: info?.source ?? PaywallSource.direct,
                      clock: _clock,
                      closeOnLeft: widget.closeOnLeft,
                    );
                    return PaywallLayoutScopeProvider(
                      scope: scope,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: paywallLayoutMaxTextScale,
                        child: Builder(
                          builder: (context) => widget.builder(context, scope),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Over the layout, so it is there from the first frame
              // whatever the layout is doing.
              Positioned(
                top: 0,
                left: widget.closeOnLeft ? Spacing.s1 : null,
                right: widget.closeOnLeft ? null : Spacing.s1,
                child: AppDismissCross(
                  label: LocaleKeys.paywall_kit_close.tr(),
                  color: tone.ink,
                  onPressed: _close,
                ),
              ),
            ],
          ),
        ),
        _Reveal(
          isVisible: widget.buyBlockVisible,
          child: PaywallBuyBlock(
            style: widget.buyStyle ?? PaywallBuyBlockStyle(tone: widget.tone),
          ),
        ),
      ],
    );
  }
}

/// Brings the buy block in. It always takes its room, so nothing above it
/// moves. Under reduce motion it is simply there.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.isVisible, required this.child});

  final bool isVisible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(AppDurations.slow);

    return IgnorePointer(
      ignoring: !isVisible,
      child: ExcludeSemantics(
        excluding: !isVisible,
        child: AnimatedSlide(
          offset: isVisible ? Offset.zero : const Offset(0, 0.2),
          duration: duration,
          curve: AppCurves.easeOut,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: duration,
            curve: AppCurves.easeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FrameClock extends ChangeNotifier implements PaywallClock {
  _FrameClock({
    required this.read,
    required this.readIsStill,
    required this.onRestart,
  });

  final double Function() read;
  final bool Function() readIsStill;
  final VoidCallback onRestart;

  @override
  double get value => read();

  @override
  bool get isStill => readIsStill();

  @override
  void restart() => onRestart();

  void tell() => notifyListeners();
}
