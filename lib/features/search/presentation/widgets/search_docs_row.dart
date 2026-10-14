import 'dart:math' as math;

import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/tap_target.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One documentation page in the search results.
///
/// Docs have no screen of their own in the app, so they get a look of their
/// own: flat text on the cream docs sheet, the page's group under its title,
/// and an arrow tipped up and out, because tapping leaves the app for the
/// browser. Settings rows point straight ahead; this one points away.
class SearchDocsRow extends StatelessWidget {
  const SearchDocsRow({
    required this.title,
    required this.group,
    required this.onTap,
    super.key,
  });

  final String title;

  /// The docs section the page sits in, such as "Self-hosting".
  final String group;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      hint: LocaleKeys.search_docs_opens_outside.tr(),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontFamilyFallback: AppTypography.fontBodyFallbacks,
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      if (group.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontBody,
                              fontFamilyFallback:
                                  AppTypography.fontBodyFallbacks,
                              fontSize: 13,
                              height: 1.35,
                              color: colors.ink3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Transform.rotate(
                    angle: -math.pi / 4,
                    child: AppGlyph(
                      GlyphType.arrow,
                      size: 16,
                      color: colors.highlight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
