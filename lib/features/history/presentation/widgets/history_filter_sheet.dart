import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/segmented_control.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Asks which past alarms to show. Returns the chosen filter, or null when the
/// sheet is dismissed without applying.
Future<HistoryFilter?> showHistoryFilterSheet(
  BuildContext context,
  HistoryFilter current,
) {
  return showModalBottomSheet<HistoryFilter>(
    context: context,
    // The sheet has to sit above the floating tab bar, which the shell draws
    // over every branch screen. Same reason as the server settings sheet.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _HistoryFilterSheet(initial: current),
  );
}

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({required this.initial});

  final HistoryFilter initial;

  @override
  State<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  late HistoryFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + bottomInset),
        child: AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                LocaleKeys.history_filter_title.tr(),
                style: AppTypography.monoBold(colors.ink, fontSize: 18),
              ),
              const SizedBox(height: Spacing.s4),

              AppSectionHeader(
                LocaleKeys.history_filter_state_header.tr(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: Spacing.s2),
              Wrap(
                spacing: Spacing.s2,
                runSpacing: Spacing.s2,
                children: <Widget>[
                  _FilterChip(
                    label: LocaleKeys.history_filter_state_all.tr(),
                    isSelected: _draft.states.isEmpty,
                    onTap: () => _set(_draft.withAllStates()),
                  ),
                  for (final state in IncidentState.values)
                    _FilterChip(
                      label: _stateLabel(state),
                      isSelected: _draft.states.contains(state),
                      onTap: () => _set(_draft.toggleState(state)),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.s4),

              AppSectionHeader(
                LocaleKeys.history_filter_window_header.tr(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: Spacing.s2),
              AppSegmentedControl<Duration>(
                items: HistoryWindows.all,
                selectedItem: _draft.window,
                labelBuilder: _windowLabel,
                onChanged: (value) => _set(_draft.withWindow(value)),
              ),
              const SizedBox(height: Spacing.s5),

              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: LocaleKeys.history_filter_reset.tr(),
                      variant: AppButtonVariant.ghost,
                      onPressed: _draft.isActive
                          ? () => _set(HistoryFilter.none)
                          : null,
                    ),
                  ),
                  const SizedBox(width: Spacing.s3),
                  Expanded(
                    child: AppButton(
                      label: LocaleKeys.history_filter_apply.tr(),
                      onPressed: () {
                        AppHaptics.capture();
                        Navigator.of(context).pop(_draft);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _set(HistoryFilter next) {
    AppHaptics.selection();
    setState(() => _draft = next);
  }

  static String _stateLabel(IncidentState state) => switch (state) {
    IncidentState.open => LocaleKeys.history_filter_state_ringing.tr(),
    IncidentState.acked => LocaleKeys.history_filter_state_acked.tr(),
    IncidentState.closed => LocaleKeys.history_filter_state_closed.tr(),
    IncidentState.expired => LocaleKeys.history_filter_state_expired.tr(),
  };

  static String _windowLabel(Duration window) {
    if (window == HistoryWindows.day) {
      return LocaleKeys.history_filter_window_24h.tr();
    }
    if (window == HistoryWindows.week) {
      return LocaleKeys.history_filter_window_7.tr();
    }
    return LocaleKeys.history_filter_window_30.tr();
  }
}

/// A chip that is either on or off. The design system's chips carry a priority
/// meaning, which these do not, so this stays local to the sheet.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s4,
            vertical: Spacing.s2,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.ink : Colors.transparent,
            borderRadius: Radii.fullAll,
            border: Border.all(
              color: isSelected ? colors.ink : colors.panelLine,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.small(
              isSelected ? colors.canvas : colors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}
