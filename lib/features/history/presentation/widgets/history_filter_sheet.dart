import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/pro_badge.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/history/domain/entities/history_filter.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Asks which past alarms to show. Returns the chosen filter, or null when the
/// sheet is dismissed without applying.
Future<HistoryFilter?> showHistoryFilterSheet(
  BuildContext context,
  HistoryFilter current, {
  required int shownDays,
}) {
  return showModalBottomSheet<HistoryFilter>(
    context: context,
    // The sheet has to sit above the floating tab bar, which the shell draws
    // over every branch screen. Same reason as the server settings sheet.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _HistoryFilterSheet(initial: current, shownDays: shownDays),
  );
}

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({required this.initial, required this.shownDays});

  final HistoryFilter initial;

  /// How many days the plan shows. Longer windows are drawn locked.
  final int shownDays;

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
                style: AppTypography.title(colors.ink, fontSize: 24),
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
              Wrap(
                spacing: Spacing.s2,
                runSpacing: Spacing.s2,
                children: <Widget>[
                  for (final window in HistoryWindows.all)
                    _FilterChip(
                      label: _windowLabel(window),
                      isSelected:
                          HistoryWindows.effective(
                            _draft.window,
                            widget.shownDays,
                          ) ==
                          window,
                      isLocked: HistoryWindows.isLocked(
                        window,
                        widget.shownDays,
                      ),
                      onTap: () => _pickWindow(window),
                    ),
                ],
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

  void _pickWindow(Duration window) {
    if (!HistoryWindows.isLocked(window, widget.shownDays)) {
      // Picking what the plan already defaults to stores the default, so the
      // filter does not read as active on Free.
      final isDefault =
          window ==
          HistoryWindows.effective(HistoryWindows.full, widget.shownDays);
      _set(_draft.withWindow(isDefault ? HistoryWindows.full : window));
      return;
    }
    // A longer window than the plan keeps. Close the sheet and open the
    // paywall for whatever unlocks long history.
    AppHaptics.selection();
    final router = GoRouter.of(context);
    final paywall = paywallLocationFor(
      getIt<FeatureAccess>().decide(AppFeature.longHistory),
      LockSource.history,
    );
    Navigator.of(context).pop();
    if (paywall != null) unawaited(router.push(paywall));
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
    if (window == HistoryWindows.month) {
      return LocaleKeys.history_filter_window_30.tr();
    }
    return LocaleKeys.history_filter_window_90.tr();
  }
}

/// A chip that is either on or off. The design system's chips carry a priority
/// meaning, which these do not, so this stays local to the sheet.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
  });

  final String label;
  final bool isSelected;

  /// The plan does not keep this window. Shows a PRO tag and opens the
  /// paywall instead of selecting.
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: isLocked
          ? LocaleKeys.history_filter_window_locked_aria_label.tr(
              namedArgs: {'window': label},
            )
          : label,
      excludeSemantics: true,
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
              color: isSelected
                  ? colors.ink
                  : colors.ink.withValues(alpha: 0.22),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppTypography.small(
                  isSelected ? colors.canvas : colors.ink3,
                ),
              ),
              if (isLocked) ...<Widget>[
                const SizedBox(width: Spacing.s2),
                ProBadge(label: LocaleKeys.paywall_pro_badge.tr()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
