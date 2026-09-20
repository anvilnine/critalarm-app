import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What sits above the plan rows, which is the only part an A/B test changes.
///
/// Every claim here is a number the relay enforces. Critical topics and the
/// daily push allowance come from `tier/caps.ts`; the history window is the
/// same table, trimmed for display by `HistoryCubit`.
class PaywallPitch extends StatelessWidget {
  const PaywallPitch({required this.variant, super.key});

  final PaywallVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case PaywallVariant.compare:
        return const _ComparePitch();
      case PaywallVariant.oneJob:
        return const _OneJobPitch();
      case PaywallVariant.straight:
      case PaywallVariant.hostedTemplate:
        return const _StraightPitch();
    }
  }
}

/// Three bullets and the self-hosting note.
class _StraightPitch extends StatelessWidget {
  const _StraightPitch();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppFeatureBullet(
          text: LocaleKeys.paywall_feature_unlimited_topics.tr(),
          glyph: GlyphType.bell,
        ),
        const SizedBox(height: 12),
        AppFeatureBullet(
          text: LocaleKeys.paywall_feature_push_limit.tr(),
          glyph: GlyphType.arrow,
        ),
        const SizedBox(height: 12),
        AppFeatureBullet(
          text: LocaleKeys.paywall_feature_history.tr(),
          glyph: GlyphType.repeat,
        ),
        const SizedBox(height: 18),
        AppNote(text: LocaleKeys.paywall_self_hosted_note.tr()),
      ],
    );
  }
}

/// Free and Hosted side by side.
class _ComparePitch extends StatelessWidget {
  const _ComparePitch();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.paywall_compare_header.tr(),
          style: TextStyle(
            color: colors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _CompareRow(
          label: LocaleKeys.paywall_compare_col_free.tr(),
          free: LocaleKeys.paywall_compare_col_free.tr(),
          hosted: LocaleKeys.paywall_compare_col_hosted.tr(),
          isHeader: true,
        ),
        _CompareRow(
          label: LocaleKeys.paywall_compare_row_topics.tr(),
          free: LocaleKeys.paywall_compare_free_topics.tr(),
          hosted: LocaleKeys.paywall_compare_hosted_topics.tr(),
        ),
        _CompareRow(
          label: LocaleKeys.paywall_compare_row_pushes.tr(),
          free: LocaleKeys.paywall_compare_free_pushes.tr(),
          hosted: LocaleKeys.paywall_compare_hosted_pushes.tr(),
        ),
        _CompareRow(
          label: LocaleKeys.paywall_compare_row_history_days.tr(),
          free: LocaleKeys.paywall_compare_free_history_days.tr(),
          hosted: LocaleKeys.paywall_compare_hosted_history_days.tr(),
        ),
        _CompareRow(
          label: LocaleKeys.paywall_compare_row_history_count.tr(),
          free: LocaleKeys.paywall_compare_free_history_count.tr(),
          hosted: LocaleKeys.paywall_compare_hosted_history_count.tr(),
          isLast: true,
        ),
        const SizedBox(height: 18),
        AppNote(text: LocaleKeys.paywall_self_hosted_note.tr()),
      ],
    );
  }
}

/// One line of the comparison. The header row reuses the same widths so the
/// columns line up without a Table.
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.free,
    required this.hosted,
    this.isHeader = false,
    this.isLast = false,
  });

  final String label;
  final String free;
  final String hosted;
  final bool isHeader;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final labelStyle = TextStyle(
      color: isHeader ? colors.ink3 : colors.ink2,
      fontSize: 13,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(isHeader ? '' : label, style: labelStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.ink3,
                fontSize: 13,
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              hosted,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Leads with the topic limit, which is the wall people hit first.
class _OneJobPitch extends StatelessWidget {
  const _OneJobPitch();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppFeatureBullet(
          text: LocaleKeys.paywall_feature_unlimited_topics.tr(),
          glyph: GlyphType.bell,
        ),
        const SizedBox(height: 12),
        AppFeatureBullet(
          text: LocaleKeys.paywall_feature_push_limit.tr(),
          glyph: GlyphType.arrow,
        ),
      ],
    );
  }
}
