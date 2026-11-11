import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/components/tap_target.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The text scale above which an [AppCardRow] value leaves the end of the
/// row and sits under the title, where the whole width is free for it.
const double kCardRowValueMaxTextScale = 1.15;

/// A white card whose first line is its title, then its rows.
///
/// The title is set in the display face at 20 points, so it reads as the
/// name of the group and never as a row's description. Rows sit edge to edge
/// with a hairline between them. Leave [title] out for a card that only
/// holds rows, such as the risky actions at the bottom of a page.
///
/// Children are usually [AppCardRow]s. Anything else gets the same hairline
/// above it, so put padded content in its own child.
class AppTitledCard extends StatelessWidget {
  const AppTitledCard({
    required this.children,
    this.title,
    this.titleTrailing,
    super.key,
  });

  /// The group's name. Null draws no title line.
  final String? title;

  /// A small widget at the end of the title line, such as a badge.
  final Widget? titleTrailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = this.title;
    final rows = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 1, color: colors.hairline),
          ),
        children[i],
      ],
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.lgAll,
        boxShadow: AppShadows.lg,
      ),
      child: ClipRRect(
        borderRadius: Radii.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: AppTypography.title(
                            colors.ink,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 8),
                      titleTrailing!,
                    ],
                  ],
                ),
              )
            else
              const SizedBox(height: 4),
            ...rows,
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// One line in an [AppTitledCard]: a title, an optional value and an arrow.
///
/// The title is in the body face. A [value] that a machine could read, such
/// as a server address, takes the mono face with [isMonoValue]. [detail] is a
/// quieter line under the title, for a child page where a row needs a few
/// words more. A row on a list of rows stays one line.
///
/// [isDanger] draws the title in the critical text colour, for Sign out and
/// Delete account. [isSelected] marks the row whose page shows in the detail
/// pane beside the list.
///
/// With [toggleValue] the row is a switch: the switch sits at the end, a tap
/// anywhere on the row flips it through [onToggle], and a screen reader hears
/// one "title, switch, on".
class AppCardRow extends StatelessWidget {
  const AppCardRow({
    required this.title,
    this.value,
    this.detail,
    this.leading,
    this.trailing,
    this.onTap,
    this.showsArrow,
    this.isMonoValue = false,
    this.isDanger = false,
    this.isSelected = false,
    this.toggleValue,
    this.onToggle,
    super.key,
  });

  final String title;

  /// What the row is set to, before the arrow. Cut before the title is.
  final String? value;

  /// A second, quieter line under the title. Two lines at most.
  final String? detail;

  /// A widget before the title, such as a small face.
  final Widget? leading;

  /// A widget in place of the value, such as a switch or a preview.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Whether the arrow shows. Null shows it when the row has a tap.
  final bool? showsArrow;

  /// Draws [value] in the mono face, for an address or an id.
  final bool isMonoValue;

  final bool isDanger;

  final bool isSelected;

  /// Makes the row a switch, on or off. Null for a row that opens something.
  final bool? toggleValue;

  /// The switch was flipped. Null greys the switch out.
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final value = this.value;
    final detail = this.detail;
    final toggleValue = this.toggleValue;
    final onToggle = this.onToggle;
    final isToggle = toggleValue != null;
    final tap = isToggle
        ? (onToggle == null ? null : () => onToggle(!toggleValue))
        : onTap;
    final arrow = !isToggle && (showsArrow ?? onTap != null);
    final valueUnderTitle =
        value != null &&
        MediaQuery.textScalerOf(context).scale(1) > kCardRowValueMaxTextScale;
    final valueStyle = isMonoValue
        ? AppTypography.mono(colors.ink3, fontSize: 13)
        : AppTypography.small(colors.ink3, fontSize: 15);

    final valueText = value == null
        ? null
        : Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: valueUnderTitle ? TextAlign.start : TextAlign.end,
            style: valueStyle,
          );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: isDanger ? colors.critText : colors.ink,
          ),
        ),
        if (valueUnderTitle) ...[
          const SizedBox(height: 2),
          ExcludeSemantics(child: valueText),
        ],
        if (detail != null && detail.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small(colors.ink3, fontSize: 13),
          ),
        ],
      ],
    );

    return Semantics(
      button: !isToggle && onTap != null,
      selected: isSelected,
      value: value,
      child: Material(
        color: isSelected ? colors.cobaltTint : Colors.transparent,
        child: InkWell(
          onTap: tap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget + 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    // A switch row's switch carries the words, so they are
                    // read once.
                    Expanded(
                      child: ExcludeSemantics(
                        excluding: isToggle,
                        child: words,
                      ),
                    ),
                    if (valueText != null && !valueUnderTitle) ...[
                      const SizedBox(width: 12),
                      // The value is chrome: it stops growing with the text
                      // size, and never takes more than 45 per cent of the
                      // row, so the title keeps its room.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.45,
                        ),
                        child: ExcludeSemantics(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: MediaQuery.textScalerOf(
                                context,
                              ).clamp(maxScaleFactor: kChromeMaxTextScale),
                            ),
                            child: valueText,
                          ),
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                    if (isToggle) ...[
                      const SizedBox(width: 12),
                      AppSwitch(
                        value: toggleValue,
                        onChanged: onToggle,
                        semanticLabel: title,
                        semanticHint: detail,
                      ),
                    ],
                    if (arrow) ...[
                      const SizedBox(width: 8),
                      AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
