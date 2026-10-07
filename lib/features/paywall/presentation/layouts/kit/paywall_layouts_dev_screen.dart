import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Developer options, Paywall layouts: every layout id, once for each
/// product. The only way into a layout until one is put in front of users.
class PaywallLayoutsDevScreen extends StatelessWidget {
  const PaywallLayoutsDevScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppScreenScaffold(
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
            child: AppSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LocaleKeys.paywall_kit_dev_note.tr(),
                    style: AppTypography.small(colors.ink3, fontSize: 13),
                  ),
                  const SizedBox(height: Spacing.s3),
                  for (final layout in PaywallLayoutId.values)
                    for (final product in PaywallProduct.values) ...[
                      AppListRow(
                        name: '${layout.key} · ${paywallProductName(product)}',
                        meta: paywallLayoutIsBuilt(layout)
                            ? ''
                            : LocaleKeys.paywall_kit_dev_not_built.tr(),
                        faceState: null,
                        trailing: AppGlyph(
                          GlyphType.arrow,
                          color: colors.ink3,
                          size: 16,
                        ),
                        onTap: () => context.push(
                          paywallLayoutLocation(
                            layout,
                            product,
                            showsUnbuilt: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.s2),
                    ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
