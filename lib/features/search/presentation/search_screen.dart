import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/list_rows.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/search/domain/entities/search_result.dart';
import 'package:critalarm/features/search/domain/entities/search_scope.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
import 'package:critalarm/features/search/presentation/cubits/search_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Search over topics, past alarms, settings and the documentation.
///
/// Drawn as a layer on top of the screen it was opened from, which is why it is
/// a route with `opaque: false`. That screen is still there, blurred, and a tap
/// off the panel goes back to it.
class SearchScreen extends StatefulWidget {
  const SearchScreen({this.scope, super.key});

  /// Which screen search was opened from. Results of that kind sort first.
  final SearchScope? scope;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchCubit>(
      create: (_) {
        final cubit = getIt<SearchCubit>();
        unawaited(cubit.load(scope: widget.scope));
        return cubit;
      },
      child: BlocBuilder<SearchCubit, SearchState>(builder: _buildLayer),
    );
  }

  Widget _buildLayer(BuildContext context, SearchState state) {
    // The route is not opaque, so there is no Material above this the way there
    // is inside a normal screen. Without one, Text falls back to the debug
    // style with yellow underlines and the ink on each row has nothing to draw
    // on. The floating tab bar carries its own Material for the same reason.
    return Material(
      type: MaterialType.transparency,
      // Top aligned and no taller than it needs to be, so everything below the
      // panel is still scrim and still closes search when tapped.
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.s4,
              Spacing.s2,
              Spacing.s4,
              Spacing.s4 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSize.contentMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SearchField(
                    controller: _controller,
                    focusNode: _focusNode,
                    scope: widget.scope,
                    onChanged: context.read<SearchCubit>().updateQuery,
                    onClear: () {
                      _controller.clear();
                      context.read<SearchCubit>().clearQuery();
                      _focusNode.requestFocus();
                    },
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: Spacing.s3),
                  Flexible(
                    child: _Panel(
                      state: state,
                      onTapResult: _open,
                      onTapRecent: _fill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Puts a recent search back in the field and searches it again.
  void _fill(BuildContext context, String query) {
    AppHaptics.selection();
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    context.read<SearchCubit>().updateQuery(query);
    _focusNode.requestFocus();
  }

  /// Opens a result. In-app results close the overlay first so the back button
  /// returns to the screen search was opened from, not to search.
  Future<void> _open(BuildContext context, SearchResult result) async {
    AppHaptics.selection();
    final cubit = context.read<SearchCubit>();
    final router = GoRouter.of(context);
    final query = cubit.state.query;

    // Recorded before navigating, because the cubit goes away with the overlay.
    await cubit.recordSearch(query);

    final url = result.externalUrl;
    if (url != null) {
      await _launch(url);
      return;
    }

    final path = result.routePath;
    if (path == null) return;
    // Closed first, so the back button from the destination returns to the
    // screen search was opened from rather than to search.
    router.pop();
    unawaited(router.push<void>(path));
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } on Exception {
      // Nothing to recover: the row simply does not navigate. The docs URL is
      // also visible on the row, so the user can still find the page.
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.scope,
    required this.onChanged,
    required this.onClear,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SearchScope? scope;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  /// The hint names what is worth typing on the screen search came from.
  String get _placeholder => switch (scope) {
    SearchScope.topics => LocaleKeys.search_placeholder_topics.tr(),
    SearchScope.history => LocaleKeys.search_placeholder_history.tr(),
    SearchScope.settings => LocaleKeys.search_placeholder_settings.tr(),
    null => LocaleKeys.search_placeholder_default.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s4),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.fullAll,
        border: Border.all(color: colors.panelLine),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: Row(
        children: <Widget>[
          AppGlyph(GlyphType.search, size: 18, color: colors.onPanelMuted),
          const SizedBox(width: Spacing.s3),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 16,
                  color: colors.onPanel,
                ),
                cursorColor: colors.highlight,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: _placeholder,
                  hintStyle: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 16,
                    color: colors.onPanelMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.s2),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              return Semantics(
                button: true,
                label: hasText
                    ? LocaleKeys.search_clear_aria_label.tr()
                    : LocaleKeys.search_close_aria_label.tr(),
                child: InkWell(
                  onTap: hasText ? onClear : onClose,
                  borderRadius: Radii.fullAll,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.s2),
                    child: AppGlyph(
                      GlyphType.close,
                      size: 16,
                      color: colors.onPanelMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.state,
    required this.onTapResult,
    required this.onTapRecent,
  });

  final SearchState state;
  final Future<void> Function(BuildContext context, SearchResult result)
  onTapResult;
  final void Function(BuildContext context, String query) onTapRecent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final children = _children(context);
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.lgAll,
        border: Border.all(color: colors.panelLine),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s2),
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    if (state.isLoading && state.results.isEmpty && state.recent.isEmpty) {
      return <Widget>[const _PanelMessage(isLoading: true)];
    }

    if (state.isBrowsing) {
      if (state.recent.isEmpty) {
        return <Widget>[
          _PanelMessage(
            title: LocaleKeys.search_hint_title.tr(),
            body: LocaleKeys.search_hint_body.tr(),
          ),
        ];
      }
      return <Widget>[
        _SectionHeader(
          title: LocaleKeys.search_recent_header.tr(),
          action: LocaleKeys.search_recent_clear.tr(),
          onAction: context.read<SearchCubit>().clearRecent,
        ),
        for (final query in state.recent)
          AppListRow(
            name: query,
            meta: '',
            faceState: null,
            trailing: AppGlyph(
              GlyphType.clock,
              size: 16,
              color: context.appColors.onPanelMuted,
            ),
            onTap: () => onTapRecent(context, query),
          ),
      ];
    }

    if (state.hasNoMatches) {
      return <Widget>[
        _PanelMessage(
          title: LocaleKeys.search_no_matches_title.tr(
            namedArgs: <String, String>{'query': state.query.trim()},
          ),
          body: LocaleKeys.search_no_matches_body.tr(),
        ),
      ];
    }

    final children = <Widget>[];
    state.sections.forEach((kind, results) {
      children.add(_SectionHeader(title: _sectionTitle(kind)));
      for (final result in results) {
        children.add(
          AppListRow(
            name: result.title,
            meta: result.subtitle,
            faceState: null,
            trailing: AppGlyph(
              result.opensExternally ? GlyphType.arrow : GlyphType.chevron,
              size: 16,
              color: context.appColors.onPanelMuted,
            ),
            onTap: () => onTapResult(context, result),
          ),
        );
      }
    });
    return children;
  }

  static String _sectionTitle(SearchResultKind kind) => switch (kind) {
    SearchResultKind.topic => LocaleKeys.search_section_topics.tr(),
    SearchResultKind.history => LocaleKeys.search_section_history.tr(),
    SearchResultKind.settings => LocaleKeys.search_section_settings.tr(),
    SearchResultKind.docs => LocaleKeys.search_section_docs.tr(),
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = action;
    if (label == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.s4,
          Spacing.s3,
          Spacing.s4,
          Spacing.s1,
        ),
        child: AppSectionHeader(title, padding: EdgeInsets.zero),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.s4,
        Spacing.s3,
        Spacing.s2,
        Spacing.s1,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: AppSectionHeader(title, padding: EdgeInsets.zero)),
          TextButton(onPressed: onAction, child: Text(label)),
        ],
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({this.title, this.body, this.isLoading = false});

  final String? title;
  final String? body;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.s6),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.s4,
        Spacing.s4,
        Spacing.s4,
        Spacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title ?? '',
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontFamilyFallback: AppTypography.fontDisplayFallbacks,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colors.onPanel,
            ),
          ),
          const SizedBox(height: Spacing.s2),
          Text(
            body ?? '',
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 14,
              height: 1.4,
              color: colors.onPanelMuted,
            ),
          ),
        ],
      ),
    );
  }
}
