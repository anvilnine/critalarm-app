import 'package:critalarm/design/components/bottom_sheets.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A one-line settings row: a title, what it is set to, and a mark that it
/// opens something. The same surface as `AppToggleRow`, so the two sit in
/// one list.
///
/// Use it for a row that opens a page or a sheet. For a choice from a list,
/// use [AppPickerRow], which draws this row and opens the sheet.
class AppValueRow extends StatelessWidget {
  const AppValueRow({
    required this.title,
    this.value,
    this.detail,
    this.onTap,
    this.glyph = GlyphType.arrow,
    this.isMonoValue = false,
    super.key,
  });

  final String title;

  /// What the row is set to, at the trailing end. Cut with an ellipsis
  /// before the title is.
  final String? value;

  /// A quieter line under the title, for a value too long for the
  /// trailing end. Two lines at most.
  final String? detail;

  /// Null greys the row out.
  final VoidCallback? onTap;

  /// The mark at the end of the row.
  final GlyphType glyph;

  /// Draws [value] in the mono face, for an id or a key.
  final bool isMonoValue;

  /// The most room the value takes, so a long one never squeezes the title
  /// out.
  static const double _valueWidth = 168;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isOff = onTap == null;
    final value = this.value;
    final detail = this.detail;

    return Semantics(
      button: !isOff,
      enabled: !isOff,
      value: value,
      child: Material(
        color: colors.cream,
        borderRadius: Radii.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.s3,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isOff ? colors.ink3 : colors.ink,
                          ),
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.small(
                              colors.ink3,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: Spacing.s3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _valueWidth),
                      child: ExcludeSemantics(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: isMonoValue
                              ? TextStyle(
                                  fontFamily: AppTypography.fontMono,
                                  fontFamilyFallback:
                                      AppTypography.fontMonoFallbacks,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.ink3,
                                )
                              : AppTypography.small(colors.ink3, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: Spacing.s2),
                  AppGlyph(glyph, color: colors.ink3, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice of an [AppPickerRow].
@immutable
class AppPickerOption<T> {
  const AppPickerOption({required this.value, required this.label, this.meta});

  final T value;
  final String label;

  /// A second, quieter line under the label in the sheet.
  final String? meta;
}

/// The most choices a picker sheet lists at its natural height. A longer
/// list opens as a sheet that scrolls.
const int pickerSheetFixedLimit = 6;

/// Whether a picker with [optionCount] choices opens the sheet that scrolls.
bool pickerSheetScrolls(int optionCount) => optionCount > pickerSheetFixedLimit;

/// What a picker row shows as its value: [valueText] when one is given,
/// then the label of the option that is [selected], then nothing.
String? pickerValueText<T>({
  required List<AppPickerOption<T>> options,
  required T? selected,
  required bool hasSelection,
  String? valueText,
}) {
  if (valueText != null) return valueText;
  if (!hasSelection) return null;
  for (final option in options) {
    if (option.value == selected) return option.label;
  }
  return null;
}

/// A row that opens a bottom sheet of choices: the title, the current value
/// as the row's value text, and a tap for the sheet. The sheet closes on a
/// pick and [onPick] gets the value.
///
/// With [hasSelection] false the sheet marks no row: a list of things to
/// open rather than a setting.
class AppPickerRow<T> extends StatelessWidget {
  const AppPickerRow({
    required this.title,
    required this.options,
    required this.onPick,
    this.selected,
    this.hasSelection = true,
    this.valueText,
    this.sheetNote,
    this.isMonoValue = false,
    super.key,
  });

  final String title;
  final List<AppPickerOption<T>> options;
  final ValueChanged<T> onPick;

  /// The value in use now. Null is a value like any other when one of
  /// [options] holds it.
  final T? selected;

  /// False for a list of things to open, which has no current value.
  final bool hasSelection;

  /// Shown in place of the selected option's label.
  final String? valueText;

  /// One or two sentences under the sheet's title.
  final String? sheetNote;

  final bool isMonoValue;

  Future<void> _open(BuildContext context) async {
    final sheetOptions = [
      for (final (index, option) in options.indexed)
        AppSheetOption<int>(
          label: option.label,
          meta: option.meta,
          value: index,
          isSelected: hasSelection && option.value == selected,
        ),
    ];
    // The index is what comes back, so a choice whose value is null is
    // still told apart from a sheet that was swiped away.
    final int? picked;
    if (pickerSheetScrolls(options.length)) {
      picked = await showExpandingSheet<int>(
        context: context,
        title: title,
        subtitle: sheetNote,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        content: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in sheetOptions)
              AppSheetOptionRow<int>(
                option: option,
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
          ],
        ),
      );
    } else {
      picked = await showAppSheet<int>(
        context: context,
        title: title,
        subtitle: sheetNote,
        options: sheetOptions,
      );
    }
    if (picked != null) onPick(options[picked].value);
  }

  @override
  Widget build(BuildContext context) {
    return AppValueRow(
      title: title,
      value: pickerValueText(
        options: options,
        selected: selected,
        hasSelection: hasSelection,
        valueText: valueText,
      ),
      glyph: GlyphType.chevron,
      isMonoValue: isMonoValue,
      onTap: options.isEmpty ? null : () => _open(context),
    );
  }
}
