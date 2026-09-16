import 'dart:async';
import 'dart:ui';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/nav_rail.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/entities/search_scope.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/features/search/presentation/widgets/search_panel.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Holds the three root destinations and floats the tab bar over whichever one
/// is showing. Each branch keeps its own history, so switching tabs and coming
/// back lands where the user left off.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<ShellCubit>();
        unawaited(cubit.refresh());
        return cubit;
      },
      child: _AppShellContent(navigationShell: navigationShell),
    );
  }
}

class _AppShellContent extends StatefulWidget {
  const _AppShellContent({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_AppShellContent> createState() => _AppShellContentState();
}

class _AppShellContentState extends State<_AppShellContent>
    with SingleTickerProviderStateMixin {
  /// Which tab the user is on, as the scope search ranks by. Index order
  /// matches the branch order in the router: Topics, History, Settings.
  static const List<SearchScope> _scopes = <SearchScope>[
    SearchScope.topics,
    SearchScope.history,
    SearchScope.settings,
  ];

  /// How far the panel sits above the bar.
  static const double _panelGap = 10;

  /// Side gutter for the bar and the panel.
  static const double _gutter = 12;

  /// The bar and the panel never get wider than this, matching the content
  /// width the rest of the app uses.
  static const double _maxWidth = 560;

  /// How far out of focus the screen behind goes while searching.
  static const double _maxBlur = 18;

  /// How much the screen behind is dimmed while searching.
  static const double _maxDim = 0.55;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Search lives at the shell, because the bar it opens into is the shell's
  /// own tab bar. It is held as a field rather than provided above the tree:
  /// a provider there reparents the branch navigators' GlobalKeys, and Flutter
  /// asserts when a GlobalKey is deactivated and reactivated in one frame.
  /// Nothing is loaded until search opens.
  final SearchCubit _search = getIt<SearchCubit>();

  /// Built in initState, not lazily. A `late final` controller that search
  /// never opens would be constructed for the first time inside dispose, and
  /// `vsync: this` looks up TickerMode on an element that is already gone.
  late final AnimationController _reveal;

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: AppDurations.enter,
      reverseDuration: AppDurations.quick,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _reveal.dispose();
    unawaited(_search.close());
    super.dispose();
  }

  SearchScope? get _scope {
    final index = widget.navigationShell.currentIndex;
    return index >= 0 && index < _scopes.length ? _scopes[index] : null;
  }

  void _openSearch() {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    _reveal.duration = context.motion(AppDurations.enter);
    _reveal.reverseDuration = context.motion(AppDurations.quick);
    unawaited(_reveal.forward());
    unawaited(_search.load(scope: _scope));
    // After the frame that swaps the bar over, so the field exists to take it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isSearching) _focusNode.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_isSearching) return;
    _focusNode.unfocus();
    _controller.clear();
    _search.clearQuery();
    unawaited(
      _reveal.reverse().whenComplete(() {
        if (mounted) setState(() => _isSearching = false);
      }),
    );
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    unawaited(context.read<ShellCubit>().refresh());
  }

  void _fillFromRecent(String query) {
    AppHaptics.selection();
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _search.updateQuery(query);
    _focusNode.requestFocus();
  }

  /// Opens a result. Search closes first, so back from the destination returns
  /// to the tab the user was on rather than to search.
  Future<void> _openResult(SearchResult result) async {
    AppHaptics.selection();
    final router = GoRouter.of(context);
    final fromBranch = widget.navigationShell.currentIndex;
    await _search.recordSearch(_search.state.query);

    final url = result.externalUrl;
    if (url != null) {
      _closeSearch();
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      } on Exception {
        // Nothing to recover: the row simply does not navigate.
      }
      return;
    }

    final path = result.routePath;
    if (path == null) return;
    _closeSearch();

    // Search opens from any tab, so a settings row can be tapped from
    // Topics. Switch tabs on purpose in that case: a push would move
    // the shell to Settings silently and the tab bar would then
    // ignore the next tap on Settings.
    final branch = shellBranchForPath(path);
    if (branch != null && branch != fromBranch) {
      router.go(path);
    } else {
      unawaited(router.push<void>(path));
    }
  }

  String get _placeholder => switch (_scope) {
    SearchScope.topics => LocaleKeys.search_placeholder_topics.tr(),
    SearchScope.history => LocaleKeys.search_placeholder_history.tr(),
    SearchScope.settings => LocaleKeys.search_placeholder_settings.tr(),
    null => LocaleKeys.search_placeholder_default.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);
    // Each of these subscribes to one part of MediaQuery. Taking the whole of
    // it with MediaQuery.of rebuilds the shell on every unrelated change.
    final padding = MediaQuery.paddingOf(context);
    final screen = MediaQuery.sizeOf(context);
    final bottomInset = padding.bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // The bar rides above the keyboard while searching, the way the pill in
    // ProblemStack does, so the field is never hidden behind it.
    final barBottom = keyboard > 0
        ? keyboard + _panelGap
        : bottomInset + AppFloatingTabBar.edgeGap;
    final panelBottom = barBottom + AppFloatingTabBar.height + _panelGap;
    final panelMaxHeight = screen.height - panelBottom - padding.top - 16;
    final width = (screen.width - _gutter * 2).clamp(0.0, _maxWidth);

    return BlocBuilder<ShellCubit, ShellHealth>(
      builder: (context, health) {
        final items = [
          AppTabItem(label: LocaleKeys.nav_topics.tr(), glyph: GlyphType.list),
          AppTabItem(
            label: LocaleKeys.nav_history.tr(),
            glyph: GlyphType.clock,
          ),
          AppTabItem(
            label: LocaleKeys.nav_settings.tr(),
            glyph: GlyphType.gear,
            showFlag: !health.isHealthy,
          ),
        ];

        return Stack(
          children: [
            Positioned.fill(child: widget.navigationShell),

            if (_isSearching) ...[
              Positioned.fill(child: _scrim()),
              Positioned(
                left: 0,
                right: 0,
                bottom: panelBottom,
                child: _panel(width, panelMaxHeight),
              ),
            ],

            // Wide enough for two panes, so the rail stands up on the left and
            // leaves the panes the full height of the display. The search bar
            // still comes up at the bottom, where the thumb is.
            if (size.isExpanded && !_isSearching)
              Positioned(
                left: AppNavRail.edgeInset,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AppNavRail(
                    currentIndex: widget.navigationShell.currentIndex,
                    items: items,
                    onSelect: _goBranch,
                    composeLabel: LocaleKeys.nav_new_topic.tr(),
                    onCompose: () => context.pushNamed(AppRoute.createTopic),
                    searchLabel: LocaleKeys.search_open_aria_label.tr(),
                    onSearch: _openSearch,
                  ),
                ),
              )
            else if (!size.isExpanded || _isSearching)
              Positioned(
                left: 0,
                right: 0,
                bottom: barBottom,
                child: Center(child: _bar(items, size, width)),
              ),
          ],
        );
      },
    );
  }

  Widget _scrim() {
    final colors = context.appColors;

    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final t = _reveal.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeSearch,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _maxBlur * t,
              sigmaY: _maxBlur * t,
            ),
            child: ColoredBox(
              color: colors.canvas.withValues(alpha: _maxDim * t),
            ),
          ),
        );
      },
    );
  }

  Widget _panel(double width, double maxHeight) {
    return BlocBuilder<SearchCubit, SearchState>(
      bloc: _search,
      builder: (context, state) => AnimatedBuilder(
        animation: CurvedAnimation(parent: _reveal, curve: AppCurves.easeOut),
        builder: (context, child) {
          final t = Curves.easeOut.transform(_reveal.value);
          return Opacity(
            opacity: t,
            // Rises the last few pixels into place, so the list reads as
            // coming up out of the bar rather than appearing on top of it.
            child: Transform.translate(
              offset: Offset(0, _panelGap * (1 - t)),
              child: child,
            ),
          );
        },
        child: Center(
          child: SizedBox(
            width: width,
            child: SearchPanel(
              state: state,
              maxHeight: maxHeight < 0 ? 0 : maxHeight,
              onTapResult: (result) => unawaited(_openResult(result)),
              onTapRecent: _fillFromRecent,
              onClearRecent: () => unawaited(_search.clearRecent()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(List<AppTabItem> items, AppSize size, double width) {
    final bar = AppFloatingTabBar(
      currentIndex: widget.navigationShell.currentIndex,
      iconsOnly: size.isNarrow,
      items: items,
      onSelect: _goBranch,
      composeLabel: LocaleKeys.nav_new_topic.tr(),
      onCompose: () => context.pushNamed(AppRoute.createTopic),
      searchLabel: LocaleKeys.search_open_aria_label.tr(),
      onSearch: _openSearch,
      isSearching: _isSearching,
      searchController: _controller,
      searchFocusNode: _focusNode,
      searchPlaceholder: _placeholder,
      onSearchChanged: _search.updateQuery,
      onSearchClose: _closeSearch,
    );

    // While searching the pill stretches to the full content width. The rest
    // of the time it hugs its slots, and five of them inside 390px is tight
    // enough that the whole bar scales down rather than clipping a label.
    if (_isSearching) return SizedBox(width: width, child: bar);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: FittedBox(fit: BoxFit.scaleDown, child: bar),
    );
  }
}
