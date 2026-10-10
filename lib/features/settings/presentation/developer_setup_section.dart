import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_step_list_parser.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/hook_up_screen.dart';
import 'package:critalarm/features/onboarding/presentation/real_ring_screen.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/settings/presentation/developer_options_group.dart';
import 'package:critalarm/features/settings/presentation/developer_options_rules.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_setup_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Whether this build and this phone show the setup controls: a build with
/// developer tools, on a phone that has the permissions step. The web
/// dashboard has none, and setup does not run there.
bool developerSetupIsShown() =>
    getIt<DeveloperOnboardingOverrides>().isActive &&
    getIt<OnboardingStepCatalog>().isAvailable(OnboardingStepId.permissions);

/// The setup controls of developer settings: pick the flow, replay it, open
/// any step, and make a step count as not done. Three groups of the list:
/// the flow, the offer step and the steps that count as not done.
///
/// Draws nothing in a build with no developer tools, and on a phone with no
/// permissions step (the web dashboard), where setup does not run.
class DeveloperSetupSection extends StatefulWidget {
  const DeveloperSetupSection({super.key});

  @override
  State<DeveloperSetupSection> createState() => _DeveloperSetupSectionState();
}

class _DeveloperSetupSectionState extends State<DeveloperSetupSection> {
  final DeveloperOnboardingOverrides _overrides =
      getIt<DeveloperOnboardingOverrides>();
  final OnboardingStepCatalog _catalog = getIt<OnboardingStepCatalog>();
  final _controller = TextEditingController();
  bool _isEditingCustom = false;
  bool _hasSeededField = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DeveloperStepListResult get _typed => parseDeveloperStepList(
    _controller.text,
    requires: _catalog.requires,
  );

  void _openCustom(DeveloperFlowChoice? choice) {
    if (!_hasSeededField && choice != null && choice.isCustom) {
      _controller.text = choice.customText!;
    }
    _hasSeededField = true;
    setState(() => _isEditingCustom = true);
  }

  void _saveCustom() {
    final result = _typed;
    // A rejected list is never stored.
    if (!result.isAccepted) return;
    unawaited(
      _overrides.chooseFlow(DeveloperFlowChoice.custom(_controller.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!developerSetupIsShown()) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _overrides,
      builder: (context, _) {
        final choice = _overrides.flowChoice;
        final showField = _isEditingCustom || (choice?.isCustom ?? false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DeveloperOptionsGroup(
              title: LocaleKeys.developer_setup_title.tr(),
              rows: [
                _flowRow(choice),
                if (showField) _customField(context),
                _redoRow(context),
                _jumpRow(context),
                ?_ringStateRow(context),
                ?_hookUpStateRow(context),
                _moreStateRow(context),
              ],
            ),
            DeveloperOptionsGroup(
              title: LocaleKeys.developer_setup_offer_title.tr(),
              rows: _offerRows(),
            ),
            DeveloperOptionsGroup(
              title: LocaleKeys.developer_setup_force_title.tr(),
              rows: _forceRows(),
            ),
          ],
        );
      },
    );
  }

  /// What the flow sheet hands back for no override and for Custom. A
  /// bundled flow hands back its own id.
  static const _noFlow = '';
  static const _customFlow = 'custom:';

  /// One row for the flow: its value is the choice in use, and its sheet
  /// lists no override, every bundled flow and Custom.
  Widget _flowRow(DeveloperFlowChoice? choice) {
    final isCustom = choice?.isCustom ?? false;
    final none = LocaleKeys.developer_setup_flow_none.tr();
    final custom = LocaleKeys.developer_setup_flow_custom.tr();
    return AppPickerRow<String>(
      title: LocaleKeys.developer_setup_flow_title.tr(),
      selected: isCustom ? _customFlow : choice?.bundledId ?? _noFlow,
      valueText: developerFlowValueText(
        bundledId: choice?.bundledId,
        isCustom: isCustom,
        none: none,
        custom: custom,
      ),
      options: [
        AppPickerOption(
          value: _noFlow,
          label: none,
          meta: LocaleKeys.developer_setup_flow_none_subtitle.tr(),
        ),
        for (final flow in BundledOnboardingFlows.all)
          AppPickerOption(
            value: flow.id,
            label: flow.id,
            meta: flow.steps.join(', '),
          ),
        AppPickerOption(
          value: _customFlow,
          label: custom,
          meta: isCustom
              ? choice!.customText
              : LocaleKeys.developer_setup_flow_custom_subtitle.tr(),
        ),
      ],
      onPick: (picked) {
        if (picked == _customFlow) {
          _openCustom(choice);
          return;
        }
        setState(() => _isEditingCustom = false);
        unawaited(
          _overrides.chooseFlow(
            picked == _noFlow ? null : DeveloperFlowChoice.bundled(picked),
          ),
        );
      },
    );
  }

  Widget _customField(BuildContext context) {
    final colors = context.appColors;
    final result = _typed;
    final hasText = _controller.text.trim().isNotEmpty;
    final lines = <String>[
      if (hasText && result.unknown.isNotEmpty)
        LocaleKeys.developer_setup_result_dropped.tr(
          args: [result.unknown.join(', ')],
        ),
      if (hasText && result.duplicates.isNotEmpty)
        LocaleKeys.developer_setup_result_duplicates.tr(
          args: [result.duplicates.join(', ')],
        ),
    ];
    String? verdict;
    var isRejected = false;
    if (hasText) {
      if (result.isAccepted) {
        verdict = LocaleKeys.developer_setup_result_accepted.tr(
          args: [result.flow!.steps.join(', ')],
        );
      } else {
        isRejected = true;
        verdict = switch (result.problem!) {
          DeveloperStepListProblem.empty =>
            LocaleKeys.developer_setup_reject_empty.tr(),
          DeveloperStepListProblem.welcomeNotFirst =>
            LocaleKeys.developer_setup_reject_welcome_first.tr(
              args: [result.problemStep!],
            ),
          DeveloperStepListProblem.orderBroken =>
            LocaleKeys.developer_setup_reject_order.tr(
              args: [result.problemStep!, result.missingStep!],
            ),
        };
        lines.add(LocaleKeys.developer_setup_reject_kept.tr());
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: LocaleKeys.developer_setup_custom_label.tr(),
            placeholder: LocaleKeys.developer_setup_custom_placeholder.tr(),
            controller: _controller,
            onChanged: (_) => setState(() {}),
          ),
          if (verdict != null) ...[
            const SizedBox(height: 6),
            Text(
              verdict,
              style: TextStyle(
                color: isRejected ? colors.crit : colors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          for (final line in lines) ...[
            const SizedBox(height: 2),
            Text(line, style: TextStyle(color: colors.ink3, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          AppButton(
            label: LocaleKeys.developer_setup_custom_apply.tr(),
            size: AppButtonSize.sm,
            onPressed: result.isAccepted ? _saveCustom : null,
          ),
        ],
      ),
    );
  }

  Widget _redoRow(BuildContext context) {
    final engine = getIt<OnboardingFlowEngine>();
    return AppValueRow(
      title: LocaleKeys.developer_setup_redo_title.tr(),
      value: engine.chooseFlow().id,
      isMonoValue: true,
      // A replay: nothing is saved, and no step is skipped for being done.
      onTap: () => unawaited(context.push('/onboarding/welcome?demo=true')),
    );
  }

  /// Every registered step, opened as a replay, and the welcome with each of
  /// the other first pages. A step that is not on this phone, or has no
  /// screen yet, is listed with the reason and opens nothing.
  Widget _jumpRow(BuildContext context) {
    bool isOpen(OnboardingStepEntry entry) =>
        _catalog.isAvailable(entry.id) && entry.route != null;
    // The welcome as it would ship with another first page: the three real
    // pages, in a replay, so nothing is saved.
    String? firstPageLocation(String query) {
      final route = OnboardingStepRegistry.entryFor(
        OnboardingStepId.welcome,
      )?.route;
      return route == null ? null : '$route?demo=true&$query';
    }

    final welcomeOptions = {
      LocaleKeys.welcome_first_pages_dev_night_falls.tr(): 'first=night',
      LocaleKeys.welcome_first_pages_dev_stays_silent.tr(): 'first=silent',
    };
    return AppPickerRow<String?>(
      title: LocaleKeys.developer_setup_jump_title.tr(),
      sheetNote: LocaleKeys.developer_setup_jump_subtitle.tr(),
      hasSelection: false,
      options: [
        for (final entry in OnboardingStepRegistry.entries) ...[
          AppPickerOption<String?>(
            value: isOpen(entry) ? '${entry.route}?demo=true' : null,
            label: entry.id,
            meta: isOpen(entry)
                ? entry.route
                : entry.route == null
                ? LocaleKeys.developer_setup_jump_no_screen.tr()
                : LocaleKeys.developer_setup_jump_not_on_phone.tr(),
          ),
          if (entry.id == OnboardingStepId.welcome && isOpen(entry))
            for (final choice in welcomeOptions.entries)
              AppPickerOption<String?>(
                value: firstPageLocation(choice.value),
                label: choice.key,
                meta: firstPageLocation(choice.value),
              ),
        ],
      ],
      onPick: (location) {
        if (location == null) return;
        unawaited(context.push(location));
      },
    );
  }

  /// One choice per state of the real ring step, each opened as a replay
  /// that is put on that state. Nothing is sent, set or saved.
  Widget? _ringStateRow(BuildContext context) => _stateRow(
    context,
    title: LocaleKeys.developer_setup_ring_states_title.tr(),
    note: LocaleKeys.developer_setup_ring_states_subtitle.tr(),
    stepId: OnboardingStepId.realRing,
    queries: {
      for (final name in RealRingScreen.replayStateNames)
        name: '${RealRingScreen.replayStateParam}=$name',
    },
  );

  /// One choice per state of the hook-up step and one per tool, each opened
  /// as a replay with made-up values. Nothing is sent, made or saved.
  Widget? _hookUpStateRow(BuildContext context) => _stateRow(
    context,
    title: LocaleKeys.developer_setup_hook_up_states_title.tr(),
    note: LocaleKeys.developer_setup_hook_up_states_subtitle.tr(),
    stepId: OnboardingStepId.hookUp,
    queries: {
      for (final name in HookUpScreen.replayStateNames)
        name: '${HookUpScreen.replayStateParam}=$name',
      for (final tool in ToolTemplate.values)
        tool.id: '${HookUpScreen.replayToolParam}=${tool.id}',
    },
  );

  /// Screens around setup that no step route reaches, each opened with
  /// made-up values. Nothing is sent or saved.
  Widget _moreStateRow(BuildContext context) {
    const locations = {
      'first_tool_acknowledged':
          CriticalAlarmScreen.previewFirstToolAckedLocation,
    };
    const pills = {
      'checklist_closed': HomeSetupPreview.closed,
      'checklist_open': HomeSetupPreview.open,
    };
    return AppPickerRow<VoidCallback>(
      title: LocaleKeys.developer_setup_more_states_title.tr(),
      sheetNote: LocaleKeys.developer_setup_more_states_subtitle.tr(),
      hasSelection: false,
      options: [
        // The setup pill on Home, with made-up rows. Its way out clears it.
        for (final entry in pills.entries)
          AppPickerOption(
            label: entry.key,
            meta: '/',
            value: () {
              homeSetupPreview.value = entry.value;
              context.go('/');
            },
          ),
        for (final entry in locations.entries)
          AppPickerOption(
            label: entry.key,
            meta: entry.value,
            value: () => unawaited(context.push(entry.value)),
          ),
      ],
      onPick: (open) => open(),
    );
  }

  /// A row whose sheet opens the step [stepId] as a replay, one choice per
  /// entry of [queries]: the choice's name and the query that puts the step
  /// on it. Null when this phone does not have the step.
  Widget? _stateRow(
    BuildContext context, {
    required String title,
    required String note,
    required String stepId,
    required Map<String, String> queries,
  }) {
    final route = OnboardingStepRegistry.entryFor(stepId)?.route;
    if (route == null || !_catalog.isAvailable(stepId)) return null;
    return AppPickerRow<String>(
      title: title,
      sheetNote: note,
      hasSelection: false,
      options: [
        for (final entry in queries.entries)
          AppPickerOption(value: entry.value, label: entry.key),
      ],
      onPick: (query) => unawaited(context.push('$route?demo=true&$query')),
    );
  }

  List<Widget> _forceRows() {
    final forced = _overrides.forcedUnsatisfied;
    return [
      for (final id in forceableOnboardingSteps)
        AppToggleRow(
          title: id,
          value: forced.contains(id),
          onChanged: _catalog.isAvailable(id)
              ? (on) => unawaited(_overrides.forceUnsatisfied(id, forced: on))
              : null,
        ),
    ];
  }

  /// The four switches of the offer step. The rows show the values in use
  /// now, from whichever source won. Changing one saves all four as the
  /// developer value, which outranks Remote Config.
  List<Widget> _offerRows() {
    final hasOverride = _overrides.offerJson != null;
    final now = getIt<OnboardingOfferGate>().chosen().config;
    final note = LocaleKeys.developer_setup_offer_subtitle.tr();

    void save({
      bool? enabled,
      PaywallProduct? Function()? cloudProduct,
      PaywallProduct? Function()? selfHostedProduct,
      String? layoutKey,
    }) => unawaited(
      _overrides.setOfferJson(
        OnboardingOfferConfig(
          enabled: enabled ?? now.enabled,
          cloudProduct: cloudProduct == null
              ? now.cloudProduct
              : cloudProduct(),
          selfHostedProduct: selfHostedProduct == null
              ? now.selfHostedProduct
              : selfHostedProduct(),
          layoutKey: layoutKey ?? now.layoutKey,
        ).encode(),
      ),
    );

    AppPickerOption<PaywallProduct?> product(PaywallProduct? product) =>
        AppPickerOption(
          value: product,
          label: product?.key ?? OnboardingOfferConfig.noProduct,
        );

    return [
      // Hands the four switches back to the next source.
      AppValueRow(
        title: LocaleKeys.developer_setup_flow_none.tr(),
        value: hasOverride
            ? LocaleKeys.developer_options_offer_clear.tr()
            : LocaleKeys.developer_options_offer_in_use.tr(),
        glyph: hasOverride ? GlyphType.close : GlyphType.check,
        onTap: () => unawaited(_overrides.setOfferJson(null)),
      ),
      AppToggleRow(
        title: OnboardingOfferConfig.enabledField,
        value: now.enabled,
        onChanged: (on) => save(enabled: on),
      ),
      AppPickerRow<PaywallProduct?>(
        title: OnboardingOfferConfig.cloudProductField,
        sheetNote: note,
        isMonoValue: true,
        selected: now.cloudProduct,
        options: [
          product(PaywallProduct.pro),
          product(PaywallProduct.hosted),
          product(null),
        ],
        onPick: (picked) => save(cloudProduct: () => picked),
      ),
      AppPickerRow<PaywallProduct?>(
        title: OnboardingOfferConfig.selfHostedProductField,
        sheetNote: note,
        isMonoValue: true,
        selected: now.selfHostedProduct,
        options: [product(PaywallProduct.pro), product(null)],
        onPick: (picked) => save(selfHostedProduct: () => picked),
      ),
      AppPickerRow<String>(
        title: OnboardingOfferConfig.layoutField,
        sheetNote: note,
        isMonoValue: true,
        selected: now.layoutKey,
        // A key no layout here has still shows as the value.
        valueText: now.layoutKey,
        options: [
          for (final layout in paywallLayoutBuilders.keys)
            AppPickerOption(value: layout.key, label: layout.key),
        ],
        onPick: (picked) => save(layoutKey: picked),
      ),
    ];
  }
}
