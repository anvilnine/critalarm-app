import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/presentation/app_icon_fit.dart';
import 'package:critalarm/features/settings/presentation/app_icon_showcase_logic.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_state.dart';
import 'package:critalarm/gen/assets.gen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The height of the page's own tail under the body (`AppPassPage`).
const double _kTailSpace = 24;

/// The size of the icon's name under the carousel.
const double _kNameSize = 24;

/// The four home screen icons as a showcase, on the App icon pass: the white
/// ground, the shared Personalize header (the label, the plan word while the
/// icons are locked, the icon in use) and the ringed back.
///
/// With the icons unlocked a person picks any of them. Everyone else sees
/// the three paid icons at full colour with the plan badge under the name.
/// The page opens for everyone. The button under the icons is the one thing
/// that opens a paywall: Unlock, or Use on an icon that turns out locked.
/// What it does goes through `keepOrOpenPaywall`, which asks `lockTapFor`.
///
/// Only reachable where the platform can change its icon: Appearance hides the
/// row that leads here, and the route sends anything else back.
class AppIconScreen extends StatelessWidget {
  const AppIconScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AppIconCubit>(),
      child: const _AppIconView(),
    );
  }
}

class _AppIconView extends StatefulWidget {
  const _AppIconView();

  @override
  State<_AppIconView> createState() => _AppIconViewState();
}

class _AppIconViewState extends State<_AppIconView>
    with TickerProviderStateMixin {
  // One slow clock drives every tile's tilt. Neighbours get a phase offset.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _welcome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _confetti = ConfettiController(duration: const Duration(seconds: 1));
  final _pages = PageController(viewportFraction: 0.6);

  late final FeatureAccess _access = getIt<FeatureAccess>();
  StreamSubscription<AppFeature>? _accessChanges;

  int _index = 0;
  bool _placed = false;
  bool _headline = false;

  @override
  void initState() {
    super.initState();
    // The plan word in the header follows the plan: it shows only while the
    // icons are locked and the plan has been read.
    _accessChanges = _access.changes.listen((feature) {
      if (feature == AppFeature.appIcons && mounted) setState(() {});
    });
    _access.planRead.addListener(_planWasRead);
  }

  void _planWasRead() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under reduce motion the tiles hold still, so the clock does not run.
    if (context.reduceMotion) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      unawaited(_clock.repeat());
    }
  }

  @override
  void dispose() {
    _access.planRead.removeListener(_planWasRead);
    unawaited(_accessChanges?.cancel());
    _clock.dispose();
    _pop.dispose();
    _welcome.dispose();
    _confetti.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/appearance');
    }
  }

  // Opens on the icon in use, once the platform has said which that is. The
  // jump waits for the end of the frame: it can run while the carousel is
  // already on screen, and moving a page view while a build is running
  // calls setState in the middle of it.
  void _place(AppIconState state) {
    if (_placed || state.status != AppIconStatus.ready) return;
    _placed = true;
    final at = AppIcon.values.indexOf(state.current);
    _index = at;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(at);
    });
  }

  void _playWelcome() {
    setState(() => _headline = true);
    if (context.reduceMotion) {
      _welcome.value = 1;
    } else {
      unawaited(_welcome.forward(from: 0));
    }
    context.read<AppIconCubit>().welcomePlayed();
  }

  void _goTo(int page) {
    unawaited(
      _pages.animateToPage(
        page,
        duration: context.motion(AppDurations.base),
        curve: AppCurves.easeOut,
      ),
    );
  }

  Future<void> _onAction(AppIconState state) async {
    final icon = AppIcon.values[_index];
    final cubit = context.read<AppIconCubit>();
    switch (iconAction(
      icon,
      unlocked: state.unlocked,
      current: state.current,
    )) {
      case IconAction.inUse:
        return;
      case IconAction.unlock:
        AppHaptics.selection();
        unawaited(_keep());
      case IconAction.use:
        final pick = await cubit.pick(icon);
        if (!mounted) return;
        if (pick == AppIconPick.changed) {
          AppHaptics.capture();
          if (!context.reduceMotion) {
            unawaited(_pop.forward(from: 0));
            _confetti.play();
          }
        } else if (pick == AppIconPick.locked) {
          unawaited(_keep());
        }
    }
  }

  /// Using or unlocking a locked icon is the act of keeping it, so the rule
  /// decides: it waits for the plan to be read, then opens the Hosted
  /// paywall only if the icons are locked.
  Future<void> _keep() =>
      keepOrOpenPaywall(context, AppFeature.appIcons, LockSource.appIcon);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppIconCubit, AppIconState>(
      listenWhen: (a, b) => b.welcome && !a.welcome,
      listener: (context, state) => _playWelcome(),
      builder: (context, state) {
        _place(state);
        final icon = AppIcon.values[_index];
        final action = iconAction(
          icon,
          unlocked: state.unlocked,
          current: state.current,
        );
        final locked = state.isLocked(icon);
        // Until the platform has said which icon shows, the header keeps the
        // value the card it grew from had.
        final cardValue = PassFrameScope.maybeOf(context)?.origin?.value;
        final tone = passToneFor(PassId.appIcon, context.appColors);
        return AppPassPage(
          tone: tone,
          label: LocaleKeys.personalize_app_icon_row.tr(),
          value: state.status == AppIconStatus.ready
              ? appIconName(state.current)
              : cardValue ?? appIconName(state.current),
          tag: lockedPlanWord(AppFeature.appIcons),
          isOn: state.current != AppIcon.standard,
          onBack: _leave,
          // The action sits pinned under the icons, so they get the rest
          // of the screen and stay its centre.
          bottomBar: _ActionBar(
            state: state,
            action: action,
            onTap: () {
              unawaited(_onAction(state));
            },
          ),
          slivers: [
            SliverLayoutBuilder(
              builder: (context, constraints) => _body(
                state: state,
                icon: icon,
                locked: locked,
                tone: tone,
                width: constraints.crossAxisExtent,
                // What the page's own header and the tail below the body
                // leave, so the body fits without a scroll.
                height:
                    constraints.viewportMainAxisExtent -
                    constraints.precedingScrollExtent -
                    _kTailSpace,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The icons, the dots and the name, sized to the room the page has: the
  /// icon shrinks before the name or its badge can be cut off, and on a short
  /// display the name and the dots stand beside the icons.
  Widget _body({
    required AppIconState state,
    required AppIcon icon,
    required bool locked,
    required PassTone tone,
    required double width,
    required double height,
  }) {
    final sideBySide = AppSize.of(context).isShort;
    final scaler = MediaQuery.textScalerOf(context);
    final textWidth = sideBySide ? width * 0.4 - kPassSidePadding : width;
    final nameHeight = _tallestName(tone.onGround, scaler, textWidth);
    final showHeadline = _headline || state.welcome;
    final fit = fitIconPage(
      width: width,
      height: height,
      nameHeight: nameHeight,
      headlineHeight: showHeadline
          ? _headlineHeight(tone.onGround, scaler, textWidth)
          : 0,
      // A slot for the badge only while some icon is locked.
      badgeHeight: state.unlocked ? 0 : iconBadgeHeight(scaler.scale(1)),
      sideBySide: sideBySide,
    );
    final dots = _Dots(
      count: AppIcon.values.length,
      index: _index,
      color: tone.onGround,
      onTap: _goTo,
    );
    final name = _NameSlot(
      icon: icon,
      locked: locked,
      color: tone.onGround,
      // The slot is as tall as the tallest name and the badge, so swiping
      // never moves the icons.
      height:
          nameHeight +
          (state.unlocked
              ? 0
              : kIconBadgeGap + iconBadgeHeight(scaler.scale(1))),
    );
    final headline = _Headline(visible: _headline, color: tone.onGround);
    final Widget content;
    if (fit.sideBySide) {
      content = Row(
        children: [
          Expanded(
            flex: 3,
            child: _carousel(state, width * 0.6, fit),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: kPassSidePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  headline,
                  name,
                  const SizedBox(height: kIconDotsGap),
                  dots,
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          headline,
          _carousel(state, width, fit),
          const SizedBox(height: kIconDotsGap),
          dots,
          const SizedBox(height: kIconNameGap),
          name,
        ],
      );
    }
    return SliverToBoxAdapter(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(0, height)),
        child: Center(child: content),
      ),
    );
  }

  /// The height of the tallest of the four names, wrapped at [width].
  double _tallestName(Color color, TextScaler scaler, double width) {
    var tallest = 0.0;
    for (final icon in AppIcon.values) {
      tallest = math.max(
        tallest,
        _textHeight(
          appIconName(icon),
          AppTypography.title(color, fontSize: _kNameSize),
          scaler,
          width,
        ),
      );
    }
    return tallest;
  }

  double _headlineHeight(Color color, TextScaler scaler, double width) =>
      _textHeight(
        LocaleKeys.settings_app_icon_welcome.tr(),
        AppTypography.headline(color, fontSize: 26),
        scaler,
        width,
      ) +
      Spacing.s3;

  double _textHeight(
    String text,
    TextStyle style,
    TextScaler scaler,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.max(1, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  Widget _carousel(AppIconState state, double width, IconPageFit fit) {
    final tile = fit.tile;
    final colors = context.appColors;
    final confettiColors = [
      colors.yellow,
      colors.cobalt,
      colors.highlight,
      colors.crit,
      colors.surface,
    ];
    final reduce = context.reduceMotion;
    final carousel = SizedBox(
      height: fit.carouselHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Behind the tiles: the burst comes out from the centred icon.
          Align(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 16,
              maxBlastForce: 28,
              minBlastForce: 10,
              colors: confettiColors,
            ),
          ),
          PageView.builder(
            controller: _pages,
            itemCount: AppIcon.values.length,
            clipBehavior: Clip.none,
            onPageChanged: (page) {
              AppHaptics.selection();
              setState(() => _index = page);
            },
            itemBuilder: (context, i) {
              final icon = AppIcon.values[i];
              return AnimatedBuilder(
                animation: Listenable.merge([_pages, _pop]),
                builder: (context, _) {
                  final page =
                      _pages.hasClients && _pages.position.haveDimensions
                      ? (_pages.page ?? _index.toDouble())
                      : _index.toDouble();
                  final look = pageLook(page - i);
                  final pop = i == _index ? _popScale(_pop.value) : 1.0;
                  return Center(
                    child: Opacity(
                      opacity: look.opacity,
                      child: Transform.scale(
                        scale: look.scale * pop,
                        child: _IconPage(
                          icon: icon,
                          index: i,
                          size: tile,
                          clock: _clock,
                          animate: !reduce,
                          locked: state.isLocked(icon),
                          current:
                              state.status == AppIconStatus.ready &&
                              state.current == icon,
                          onTap: () => _goTo(i),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
    if (reduce) return carousel;
    // The welcome: the carousel slides in from the right.
    return AnimatedBuilder(
      animation: _welcome,
      child: carousel,
      builder: (context, child) {
        final t = _headline ? AppCurves.easeOut.transform(_welcome.value) : 1.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - t) * width * 0.6, 0),
            child: child,
          ),
        );
      },
    );
  }

  /// 1 -> 1.08 -> 1 over the pop, with a spring on the way back.
  static double _popScale(double t) {
    if (t <= 0 || t >= 1) return 1;
    return t < 0.4
        ? 1 + 0.08 * AppCurves.easeOut.transform(t / 0.4)
        : 1.08 - 0.08 * AppCurves.easeSpring.transform((t - 0.4) / 0.6);
  }
}

/// The icon's name, with the plan badge under it while the icon is locked.
/// It is [height] tall for every icon, so swiping never moves what is above.
class _NameSlot extends StatelessWidget {
  const _NameSlot({
    required this.icon,
    required this.locked,
    required this.color,
    required this.height,
  });

  final AppIcon icon;
  final bool locked;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: context.motion(AppDurations.quick),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: Column(
          key: ValueKey(icon),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appIconName(icon),
              textAlign: TextAlign.center,
              style: AppTypography.title(color, fontSize: _kNameSize),
            ),
            // The button already says In use, so only a locked icon gets a
            // mark here: the plan badge, with its lock.
            if (locked) ...[
              const SizedBox(height: kIconBadgeGap),
              const AccessLock.inline(
                feature: AppFeature.appIcons,
                source: LockSource.appIcon,
                child: FeatureLockBadge(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Your extra icons", fading in above the carousel on the first visit.
class _Headline extends StatelessWidget {
  const _Headline({required this.visible, required this.color});

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final line = visible
        ? Padding(
            padding: const EdgeInsets.only(bottom: Spacing.s3),
            child: Text(
              LocaleKeys.settings_app_icon_welcome.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.headline(color, fontSize: 26),
            ),
          )
        : const SizedBox.shrink();
    // Under reduce motion the line is just there. An AnimatedSize with no
    // time to run marks itself for layout while the fill-remaining sliver
    // is still laying it out, which Flutter reports as an error.
    if (context.reduceMotion) return line;
    return AnimatedSize(
      duration: AppDurations.base,
      curve: AppCurves.easeOut,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDurations.slow,
        child: line,
      ),
    );
  }
}

/// The pinned action: Use this icon, the status for the icon in use, or
/// Unlock, with the failure note above it when the platform refused.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.action,
    required this.onTap,
  });

  final AppIconState state;
  final IconAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kPassSidePadding,
        Spacing.s2,
        kPassSidePadding,
        Spacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.failed) ...[
            AppNote(text: LocaleKeys.settings_app_icon_failed.tr()),
            const SizedBox(height: Spacing.s3),
          ],
          // The icon in use is a status, not a disabled button, which read
          // as a dead primary. Same height as the button, so the slot never
          // shifts as the carousel moves.
          if (action == IconAction.inUse)
            _InUseStatus(
              label: LocaleKeys.settings_app_icon_action_in_use.tr(),
            )
          else
            AppButton(
              label: switch (action) {
                IconAction.use => LocaleKeys.settings_app_icon_action_use.tr(),
                // Names no plan: the badge under the icon's name does, and
                // the paywall shows what unlocks it.
                IconAction.unlock =>
                  LocaleKeys.settings_app_icon_action_unlock.tr(),
                IconAction.inUse => '',
              },
              isFullWidth: true,
              isLoading: state.saving != null,
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

/// One tile: the artwork, tilting by itself. A locked one is drawn the
/// same as an open one. The badge under its name says it is locked.
class _IconPage extends StatelessWidget {
  const _IconPage({
    required this.icon,
    required this.index,
    required this.size,
    required this.clock,
    required this.animate,
    required this.locked,
    required this.current,
    required this.onTap,
  });

  final AppIcon icon;
  final int index;
  final double size;
  final Animation<double> clock;
  final bool animate;
  final bool locked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = locked
        ? LocaleKeys.settings_app_icon_page_locked
        : current
        ? LocaleKeys.settings_app_icon_page_in_use
        : LocaleKeys.settings_app_icon_page_ready;
    return Semantics(
      button: true,
      selected: current,
      label: label.tr(namedArgs: {'name': appIconName(icon)}),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TiltShowcase(
              clock: clock,
              phase: index * 1.3,
              animate: animate,
              // Under reduce motion the icon stands upright.
              maxAngle: animate ? 11 * math.pi / 180 : 0,
              borderRadius: BorderRadius.circular(size * 230 / 1024),
              child: AppIconPreview(icon: icon, size: size),
            ),
          ],
        ),
      ),
    );
  }
}

/// "In use": an ink-outlined pill with a filled check. Not
/// tappable, and the height of a medium [AppButton] (48).
class _InUseStatus extends StatelessWidget {
  const _InUseStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: Radii.fullAll,
        border: Border.all(color: colors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.ink,
            ),
            alignment: Alignment.center,
            child: AppGlyph(
              GlyphType.check,
              size: 13,
              color: colors.canvas,
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(width: 10),
          // Wraps at a large text size and never overflows.
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontDisplay,
                fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.16,
                color: colors.ink,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots. Each one is a button, and the row answers increase and
/// decrease so a screen reader can step through the icons.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.index,
    required this.color,
    required this.onTap,
  });

  final int count;
  final int index;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: LocaleKeys.settings_app_icon_page_position.tr(
        namedArgs: {'index': '${index + 1}', 'count': '$count'},
      ),
      onIncrease: index < count - 1 ? () => onTap(index + 1) : null,
      onDecrease: index > 0 ? () => onTap(index - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedContainer(
                    duration: context.motion(AppDurations.quick),
                    width: i == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index ? color : color.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The name of [icon], already translated.
String appIconName(AppIcon icon) => switch (icon) {
  AppIcon.standard => LocaleKeys.settings_app_icon_default.tr(),
  AppIcon.crowned => LocaleKeys.settings_app_icon_crowned.tr(),
  AppIcon.shades => LocaleKeys.settings_app_icon_shades.tr(),
  AppIcon.shadesCrown => LocaleKeys.settings_app_icon_shades_crown.tr(),
};

/// [icon] drawn the way a home screen draws it, corners and all.
class AppIconPreview extends StatelessWidget {
  const AppIconPreview({
    required this.icon,
    required this.size,
    this.dimmed = false,
    super.key,
  });

  final AppIcon icon;
  final double size;

  /// Faded, for a Pro icon this device cannot pick yet.
  final bool dimmed;

  AssetGenImage get _image => switch (icon) {
    AppIcon.standard => Assets.appIcons.appIcon,
    AppIcon.crowned => Assets.appIcons.appIconProCrowned,
    AppIcon.shades => Assets.appIcons.appIconProShades,
    AppIcon.shadesCrown => Assets.appIcons.appIconProShadesCrown,
  };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: ClipRRect(
        // The iOS icon corner: 230 on a 1024 square.
        borderRadius: BorderRadius.circular(size * 230 / 1024),
        child: _image.image(
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
