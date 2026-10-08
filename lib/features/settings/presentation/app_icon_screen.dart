import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/presentation/app_icon_showcase_logic.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_state.dart';
import 'package:critalarm/gen/assets.gen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The four home screen icons as a showcase. Pro picks any of them; everyone
/// else sees the three Pro icons tilting and glinting with a lock, and the
/// button under them opens the paywall.
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

  int _index = 0;
  bool _placed = false;
  bool _headline = false;

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

  // Opens on the icon in use, once the platform has said which that is.
  void _place(AppIconState state) {
    if (_placed || state.status != AppIconStatus.ready) return;
    _placed = true;
    final at = AppIcon.values.indexOf(state.current);
    _index = at;
    if (_pages.hasClients) {
      _pages.jumpToPage(at);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(at);
      });
    }
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
        unawaited(_openPaywall());
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
          unawaited(_openPaywall());
        }
    }
  }

  Future<void> _openPaywall() =>
      openPaywallForFeature(context, AppFeature.appIcons, LockSource.appIcon);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppIconCubit, AppIconState>(
      listenWhen: (a, b) => b.welcome && !a.welcome,
      listener: (context, state) => _playWelcome(),
      builder: (context, state) {
        _place(state);
        final colors = context.appColors;
        final icon = AppIcon.values[_index];
        final action = iconAction(
          icon,
          unlocked: state.unlocked,
          current: state.current,
        );
        final locked = state.isLocked(icon);
        return AppScreenScaffold(
          // Full screen, on the root navigator: no tab bar to leave room for.
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.settings_app_icon_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: _leave,
            ),
          ),
          // The action sits pinned above the tab bar, so the icons get the
          // rest of the screen and stay its centre.
          bottomBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.failed) ...[
                AppNote(text: LocaleKeys.settings_app_icon_failed.tr()),
                const SizedBox(height: Spacing.s3),
              ],
              if (locked) ...[
                Text(
                  LocaleKeys.settings_app_icon_pro_feature.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.small(colors.onCanvas),
                ),
                const SizedBox(height: Spacing.s2),
              ],
              // The icon in use is a status, not a disabled button, which read
              // as a dead primary. Same height as the button, so the slot
              // never shifts as the carousel moves.
              if (action == IconAction.inUse)
                _InUseStatus(
                  label: LocaleKeys.settings_app_icon_action_in_use.tr(),
                )
              else
                AppButton(
                  label: switch (action) {
                    IconAction.use =>
                      LocaleKeys.settings_app_icon_action_use.tr(),
                    IconAction.unlock =>
                      LocaleKeys.settings_app_icon_go_pro.tr(),
                    IconAction.inUse => '',
                  },
                  isFullWidth: true,
                  isLoading: state.saving != null,
                  onPressed: () => unawaited(_onAction(state)),
                ),
            ],
          ),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.s6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Headline(visible: _headline, colors: colors),
                    // Screen width, not a LayoutBuilder: the fill-remaining
                    // sliver measures its child's intrinsic height first.
                    _carousel(state, MediaQuery.sizeOf(context).width),
                    const SizedBox(height: Spacing.s3),
                    _Dots(
                      count: AppIcon.values.length,
                      index: _index,
                      onTap: _goTo,
                    ),
                    const SizedBox(height: Spacing.s4),
                    AnimatedSwitcher(
                      duration: context.motion(AppDurations.quick),
                      child: Column(
                        key: ValueKey(icon),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            appIconName(icon),
                            style: AppTypography.title(
                              colors.onCanvas,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: Spacing.s2),
                          // The button already says In use, so only a locked
                          // icon gets a mark here: the plan badge, with its
                          // lock.
                          if (locked)
                            const AccessLock.inline(
                              feature: AppFeature.appIcons,
                              source: LockSource.appIcon,
                              child: FeatureLockBadge(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _carousel(AppIconState state, double width) {
    final tile = showcaseTileSize(width);
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
      height: tile + 56,
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

/// "Your extra icons", fading in above the carousel on the first visit.
class _Headline extends StatelessWidget {
  const _Headline({required this.visible, required this.colors});

  final bool visible;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: context.motion(AppDurations.base),
      curve: AppCurves.easeOut,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: context.motion(AppDurations.slow),
        child: visible
            ? Padding(
                padding: const EdgeInsets.only(bottom: Spacing.s3),
                child: Text(
                  LocaleKeys.settings_app_icon_welcome.tr(),
                  style: AppTypography.headline(colors.onCanvas, fontSize: 26),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// One tile: the artwork, tilting by itself, with a lock when it needs Pro.
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

  // Slightly desaturated, so a locked icon looks held back, not greyed out.
  static const _tease = ColorFilter.matrix(<double>[
    0.8, 0.15, 0.05, 0, 0, //
    0.1, 0.85, 0.05, 0, 0, //
    0.1, 0.15, 0.75, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final art = AppIconPreview(icon: icon, size: size);
    final face = locked ? ColorFiltered(colorFilter: _tease, child: art) : art;
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
              borderRadius: BorderRadius.circular(size * 230 / 1024),
              child: face,
            ),
          ],
        ),
      ),
    );
  }
}

/// "This is your icon": an ink-outlined pill with a filled check. Not
/// tappable, and the height of a medium [AppButton] (48).
class _InUseStatus extends StatelessWidget {
  const _InUseStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
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
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontFamilyFallback: AppTypography.fontDisplayFallbacks,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.16,
              color: colors.ink,
              height: 1,
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
  const _Dots({required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
                      color: i == index
                          ? colors.onCanvas
                          : colors.onCanvasMuted.withValues(alpha: 0.4),
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
