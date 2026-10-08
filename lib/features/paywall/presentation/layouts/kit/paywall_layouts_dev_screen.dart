import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tile.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:go_router/go_router.dart';

/// Developer options, Paywall layouts: what each product's paywall opens,
/// picked in three steps. An intro, a paywall, then what plays after a
/// purchase, each from a sheet of small phones that play the real thing.
/// "Open it" plays all three as a user would see them: in a build that
/// skips the store its buy button confirms at once. Under them, the
/// routing choices that are not one named layout, and a list of every
/// layout id to pin one by its key.
///
/// The picks are the developer switches, so what is chosen here is also
/// what every entry point in this build opens.
class PaywallLayoutsDevScreen extends StatefulWidget {
  const PaywallLayoutsDevScreen({super.key});

  @override
  State<PaywallLayoutsDevScreen> createState() =>
      _PaywallLayoutsDevScreenState();
}

/// The layouts this build can draw, in the order they are listed.
List<PaywallLayoutId> get _layouts => [
  for (final layout in PaywallLayoutId.values)
    if (paywallLayoutIsBuilt(layout)) layout,
];

/// The intros this build can play, `none` first.
List<PaywallIntroId> get _intros => [
  for (final intro in PaywallIntroId.values)
    if (paywallIntroIsBuilt(intro)) intro,
];

/// What this build can play after a purchase, `none` first.
List<PaywallThanksId> get _allThanks => [
  for (final thanks in PaywallThanksId.values)
    if (paywallThanksIsBuilt(thanks)) thanks,
];

String _introLabel(PaywallIntroId intro) => paywallIntroName(intro);

String _routeLabel(PaywallLayoutSetting? setting) {
  if (setting == null) {
    return LocaleKeys.settings_developer_paywall_route_follow.tr();
  }
  if (setting.isShipped) {
    return LocaleKeys.settings_developer_paywall_route_shipped.tr();
  }
  if (setting.isAuto) {
    return LocaleKeys.settings_developer_paywall_route_auto.tr();
  }
  final layout = setting.layout;
  return layout == null ? setting.storedKey : paywallLayoutName(layout);
}

class _PaywallLayoutsDevScreenState extends State<PaywallLayoutsDevScreen> {
  PaywallProduct _product = PaywallProduct.hosted;

  DevPaywallLayoutSwitches get _switches => getIt<DevPaywallLayoutSwitches>();

  DevPaywallLayoutSwitch get _layoutSwitch => switch (_product) {
    PaywallProduct.hosted => _switches.hosted,
    PaywallProduct.pro => _switches.pro,
  };

  DevPaywallIntroSwitch get _introSwitch => switch (_product) {
    PaywallProduct.hosted => _switches.hostedIntro,
    PaywallProduct.pro => _switches.proIntro,
  };

  DevPaywallThanksSwitch get _thanksSwitch => switch (_product) {
    PaywallProduct.hosted => _switches.hostedThanks,
    PaywallProduct.pro => _switches.proThanks,
  };

  /// The layout "Open it" opens: the one pinned, or the fallback while the
  /// routing is left to something else.
  PaywallLayoutId get _layout =>
      _layoutSwitch.value?.layout ?? paywallFallbackLayout;

  Future<void> _pickIntro() async {
    final product = _product;
    final introSwitch = _introSwitch;
    final layout = _layout;
    await showAppSheet<void>(
      context: context,
      title: LocaleKeys.paywall_picker_intro_sheet_title.tr(),
      subtitle: LocaleKeys.paywall_picker_sheet_note.tr(),
      content: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TileRow(
            count: _intros.length,
            selected: _intros.indexOf(introSwitch.value ?? PaywallIntroId.none),
            tileBuilder: (context, index) {
              final intro = _intros[index];
              return PaywallIntroTile(
                intro: intro,
                layout: layout,
                product: product,
                label: _introLabel(intro),
                isSelected: intro == introSwitch.value,
                onTap: () {
                  unawaited(introSwitch.setIntro(intro));
                  Navigator.of(sheetContext).pop();
                },
              );
            },
          ),
          const SizedBox(height: Spacing.s3),
          AppButton(
            label: LocaleKeys.settings_developer_paywall_route_follow.tr(),
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: () {
              unawaited(introSwitch.setIntro(null));
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickThanks() async {
    final product = _product;
    final thanksSwitch = _thanksSwitch;
    final layout = _layout;
    await showAppSheet<void>(
      context: context,
      title: LocaleKeys.paywall_thanks_picker_sheet_title.tr(),
      subtitle: LocaleKeys.paywall_picker_sheet_note.tr(),
      content: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TileRow(
            count: _allThanks.length,
            selected: _allThanks.indexOf(
              thanksSwitch.value ?? PaywallThanksId.none,
            ),
            tileBuilder: (context, index) {
              final thanks = _allThanks[index];
              return PaywallThanksTile(
                thanks: thanks,
                layout: layout,
                product: product,
                label: paywallThanksName(thanks),
                isSelected: thanks == thanksSwitch.value,
                onTap: () {
                  unawaited(thanksSwitch.setThanks(thanks));
                  Navigator.of(sheetContext).pop();
                },
              );
            },
          ),
          const SizedBox(height: Spacing.s3),
          AppButton(
            label: LocaleKeys.settings_developer_paywall_route_follow.tr(),
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: () {
              unawaited(thanksSwitch.setThanks(null));
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickLayout() async {
    final product = _product;
    final layoutSwitch = _layoutSwitch;
    await showAppSheet<void>(
      context: context,
      title: LocaleKeys.paywall_picker_paywall_sheet_title.tr(),
      subtitle: LocaleKeys.paywall_picker_sheet_note.tr(),
      content: (sheetContext) => _TileRow(
        count: _layouts.length,
        selected: math.max(
          0,
          _layouts.indexOf(layoutSwitch.value?.layout ?? _layouts.first),
        ),
        tileBuilder: (context, index) {
          final layout = _layouts[index];
          return PaywallLayoutTile(
            layout: layout,
            product: product,
            label: paywallLayoutName(layout),
            isSelected: layout == layoutSwitch.value?.layout,
            onTap: () {
              unawaited(
                layoutSwitch.setSetting(PaywallLayoutSetting.pinned(layout)),
              );
              Navigator.of(sheetContext).pop();
            },
          );
        },
      ),
    );
  }

  void _open() => unawaited(
    context.push(
      paywallLayoutLocation(
        _layout,
        _product,
        intro: _introSwitch.value ?? PaywallIntroId.none,
        thanks: _thanksSwitch.value ?? PaywallThanksId.none,
        showsUnbuilt: true,
        isTryOut: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final arrow = AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16);

    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: LocaleKeys.paywall_kit_dev_page_title.tr(),
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.common_back.tr(),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/settings/developer'),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _switches.hosted,
                _switches.pro,
                _switches.hostedIntro,
                _switches.proIntro,
                _switches.hostedThanks,
                _switches.proThanks,
              ]),
              builder: (context, _) {
                final setting = _layoutSwitch.value;
                final intro = _introSwitch.value;
                final thanks = _thanksSwitch.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSegmentedControl<PaywallProduct>(
                      items: PaywallProduct.values,
                      selectedItem: _product,
                      labelBuilder: paywallProductName,
                      onChanged: (product) =>
                          setState(() => _product = product),
                    ),
                    const SizedBox(height: Spacing.s3),
                    AppSheet(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppListRow(
                            name: LocaleKeys.paywall_picker_intro_row.tr(),
                            meta: intro == null
                                ? LocaleKeys.paywall_picker_follows_remote.tr()
                                : _introLabel(intro),
                            faceState: null,
                            trailing: arrow,
                            onTap: _pickIntro,
                          ),
                          const SizedBox(height: Spacing.s2),
                          AppListRow(
                            name: LocaleKeys.paywall_picker_paywall_row.tr(),
                            meta: setting == null
                                ? LocaleKeys.paywall_picker_follows_remote.tr()
                                : _routeLabel(setting),
                            faceState: null,
                            trailing: arrow,
                            onTap: _pickLayout,
                          ),
                          const SizedBox(height: Spacing.s2),
                          AppListRow(
                            name: LocaleKeys.paywall_thanks_picker_row.tr(),
                            meta: thanks == null
                                ? LocaleKeys.paywall_picker_follows_remote.tr()
                                : paywallThanksName(thanks),
                            faceState: null,
                            trailing: arrow,
                            onTap: _pickThanks,
                          ),
                          const SizedBox(height: Spacing.s3),
                          AppButton(
                            label: LocaleKeys.paywall_picker_open.tr(),
                            isFullWidth: true,
                            onPressed: _open,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.s3),
                    AppSheet(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LocaleKeys.paywall_picker_routing_header.tr(),
                            style: AppTypography.small(
                              colors.ink3,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: Spacing.s2),
                          for (final choice in <PaywallLayoutSetting?>[
                            null,
                            PaywallLayoutSetting.shipped,
                            PaywallLayoutSetting.auto,
                          ]) ...[
                            AppListRow(
                              name: _routeLabel(choice),
                              meta: '',
                              faceState: null,
                              trailing: choice == setting
                                  ? AppGlyph(
                                      GlyphType.check,
                                      color: colors.highlight,
                                      size: 16,
                                    )
                                  : null,
                              onTap: () => unawaited(
                                _layoutSwitch.setSetting(choice),
                              ),
                            ),
                            const SizedBox(height: Spacing.s1),
                          ],
                          // Every id, the ones with no layout of their own
                          // too: the tiles above only list what is built.
                          AppPickerRow<PaywallLayoutId>(
                            title: LocaleKeys.developer_options_by_key_title
                                .tr(),
                            sheetNote: LocaleKeys.developer_options_by_key_note
                                .tr(),
                            isMonoValue: true,
                            selected: setting?.layout,
                            hasSelection: setting?.layout != null,
                            options: [
                              for (final layout in PaywallLayoutId.values)
                                AppPickerOption(
                                  value: layout,
                                  label: layout.key,
                                  meta: paywallLayoutIsBuilt(layout)
                                      ? paywallLayoutName(layout)
                                      : LocaleKeys
                                            .developer_options_by_key_unbuilt
                                            .tr(),
                                ),
                            ],
                            onPick: (layout) => unawaited(
                              _layoutSwitch.setSetting(
                                PaywallLayoutSetting.pinned(layout),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of tiles to swipe through, opened on the chosen one.
///
/// It builds only the tiles on screen, about three on a phone, so at most
/// that many paywalls play at once however many there are to pick from.
class _TileRow extends StatefulWidget {
  const _TileRow({
    required this.count,
    required this.selected,
    required this.tileBuilder,
  });

  final int count;
  final int selected;
  final IndexedWidgetBuilder tileBuilder;

  @override
  State<_TileRow> createState() => _TileRowState();
}

class _TileRowState extends State<_TileRow> {
  static const double _width = PaywallPhoneTile.defaultWidth;
  static const double _gap = Spacing.s3;

  /// Room above and beside the tiles for the mark on the chosen one.
  static const double _edge = Spacing.s2;

  late final ScrollController _scroll = ScrollController(
    // The chosen tile is second from the left when it can be.
    initialScrollOffset: math.max(0, widget.selected - 1) * (_width + _gap),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PaywallPhoneTile.heightFor(_width) + _edge,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        // Nothing is built ahead: a tile off screen has no clock.
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        padding: const EdgeInsets.fromLTRB(_edge, _edge, _edge, 0),
        itemCount: widget.count,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: widget.tileBuilder,
      ),
    );
  }
}
