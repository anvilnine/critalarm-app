import 'package:critalarm/design/components/tap_target.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What search shows when nothing matched: a card with the watching face, what
/// was typed, one line of help and three queries to try. The same three the
/// Search guide teaches.
class SearchNoMatches extends StatelessWidget {
  const SearchNoMatches({
    required this.query,
    required this.onTapExample,
    super.key,
  });

  final String query;
  final ValueChanged<String> onTapExample;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final examples = <String>[
      LocaleKeys.search_example_one.tr(),
      LocaleKeys.search_example_two.tr(),
      LocaleKeys.search_example_three.tr(),
    ];

    return Container(
      width: double.infinity,
      // The example chips are 40 high in 48 tap boxes, which reach 4 past
      // them: 4 less below the last row and above the first.
      padding: const EdgeInsets.fromLTRB(
        Spacing.s4,
        Spacing.s4,
        Spacing.s4,
        Spacing.s4 - 4,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.xlAll,
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const FaceWidget(state: FaceState.watching, size: 64),
          const SizedBox(height: Spacing.s3),
          Text(
            LocaleKeys.search_no_matches_title.tr(
              namedArgs: <String, String>{'query': query},
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title(colors.ink, fontSize: 22),
          ),
          const SizedBox(height: Spacing.s2),
          Text(
            LocaleKeys.search_no_matches_body.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.small(colors.ink3),
          ),
          const SizedBox(height: Spacing.s3 - 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Spacing.s2,
            // No runSpacing: it was 8 between 40 high chips, and the boxes
            // are 8 taller than the chips.
            children: <Widget>[
              for (final example in examples)
                _ExampleChip(
                  label: example,
                  onTap: () => onTapExample(example),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppTapTarget(
        minWidth: 0,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.fullAll,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.cream,
              borderRadius: Radii.fullAll,
            ),
            child: Text(
              label,
              style: AppTypography.mono(colors.ink, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
