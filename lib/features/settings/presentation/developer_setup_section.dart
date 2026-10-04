import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_step_list_parser.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/real_ring_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The setup controls of developer settings: pick the flow, replay it, open
/// any step, and make a step count as not done.
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
    // Setup permissions exist on a phone only, so a phone without that step
    // has no setup to look at.
    if (!_overrides.isActive ||
        !_catalog.isAvailable(OnboardingStepId.permissions)) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: _overrides,
      builder: (context, _) {
        final choice = _overrides.flowChoice;
        final showField = _isEditingCustom || (choice?.isCustom ?? false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Heading(
                title: LocaleKeys.developer_setup_title.tr(),
                subtitle: LocaleKeys.developer_setup_subtitle.tr(),
              ),
              _flowRows(context, choice),
              if (showField) _customField(context),
              const SizedBox(height: 14),
              _redoRow(context),
              const SizedBox(height: 14),
              _Heading(
                title: LocaleKeys.developer_setup_jump_title.tr(),
                subtitle: LocaleKeys.developer_setup_jump_subtitle.tr(),
              ),
              _jumpRows(context),
              const SizedBox(height: 14),
              _Heading(
                title: LocaleKeys.developer_setup_ring_states_title.tr(),
                subtitle: LocaleKeys.developer_setup_ring_states_subtitle.tr(),
              ),
              _ringStateRows(context),
              const SizedBox(height: 14),
              _Heading(
                title: LocaleKeys.developer_setup_force_title.tr(),
                subtitle: LocaleKeys.developer_setup_force_subtitle.tr(),
              ),
              _forceRows(),
            ],
          ),
        );
      },
    );
  }

  Widget _flowRows(BuildContext context, DeveloperFlowChoice? choice) {
    final colors = context.appColors;
    Widget check({required bool isSelected}) => isSelected
        ? AppGlyph(GlyphType.check, color: colors.highlight, size: 16)
        : const SizedBox.shrink();
    return Column(
      children: [
        AppListRow(
          name: LocaleKeys.developer_setup_flow_none.tr(),
          meta: LocaleKeys.developer_setup_flow_none_subtitle.tr(),
          faceState: null,
          trailing: check(isSelected: choice == null),
          onTap: () {
            setState(() => _isEditingCustom = false);
            unawaited(_overrides.chooseFlow(null));
          },
        ),
        for (final flow in BundledOnboardingFlows.all) ...[
          const SizedBox(height: 4),
          AppListRow(
            name: flow.id,
            meta: flow.steps.join(', '),
            faceState: null,
            trailing: check(
              isSelected: choice == DeveloperFlowChoice.bundled(flow.id),
            ),
            onTap: () {
              setState(() => _isEditingCustom = false);
              unawaited(
                _overrides.chooseFlow(DeveloperFlowChoice.bundled(flow.id)),
              );
            },
          ),
        ],
        const SizedBox(height: 4),
        AppListRow(
          name: LocaleKeys.developer_setup_flow_custom.tr(),
          meta: choice?.isCustom ?? false
              ? choice!.customText!
              : LocaleKeys.developer_setup_flow_custom_subtitle.tr(),
          faceState: null,
          trailing: check(isSelected: choice?.isCustom ?? false),
          onTap: () => _openCustom(choice),
        ),
      ],
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
      padding: const EdgeInsets.only(top: 8),
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
    return AppListRow(
      name: LocaleKeys.developer_setup_redo_title.tr(),
      meta: LocaleKeys.developer_setup_redo_subtitle.tr(
        args: [engine.chooseFlow().id],
      ),
      faceState: null,
      trailing: AppGlyph(
        GlyphType.arrow,
        color: context.appColors.ink3,
        size: 16,
      ),
      // A replay: nothing is saved, and no step is skipped for being done.
      onTap: () => unawaited(context.push('/onboarding/welcome?demo=true')),
    );
  }

  Widget _jumpRows(BuildContext context) {
    return Column(
      children: [
        for (final entry in OnboardingStepRegistry.entries) ...[
          if (entry != OnboardingStepRegistry.entries.first)
            const SizedBox(height: 4),
          _jumpRow(context, entry),
        ],
      ],
    );
  }

  Widget _jumpRow(BuildContext context, OnboardingStepEntry entry) {
    final route = entry.route;
    final isOpen = _catalog.isAvailable(entry.id) && route != null;
    final meta = isOpen
        ? route
        : route == null
        ? LocaleKeys.developer_setup_jump_no_screen.tr()
        : LocaleKeys.developer_setup_jump_not_on_phone.tr();
    return AppListRow(
      name: entry.id,
      meta: meta,
      faceState: null,
      isQuiet: !isOpen,
      trailing: isOpen
          ? AppGlyph(
              GlyphType.arrow,
              color: context.appColors.ink3,
              size: 16,
            )
          : null,
      onTap: isOpen ? () => unawaited(context.push('$route?demo=true')) : null,
    );
  }

  /// One row per state of the real ring step, each opened as a replay that
  /// is put on that state. Nothing is sent, set or saved.
  Widget _ringStateRows(BuildContext context) {
    final route = OnboardingStepRegistry.entryFor(
      OnboardingStepId.realRing,
    )?.route;
    if (route == null || !_catalog.isAvailable(OnboardingStepId.realRing)) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final name in RealRingScreen.replayStateNames) ...[
          if (name != RealRingScreen.replayStateNames.first)
            const SizedBox(height: 4),
          AppListRow(
            name: name,
            meta: route,
            faceState: null,
            trailing: AppGlyph(
              GlyphType.arrow,
              color: context.appColors.ink3,
              size: 16,
            ),
            onTap: () => unawaited(
              context.push(
                '$route?demo=true&${RealRingScreen.replayStateParam}=$name',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _forceRows() {
    final forced = _overrides.forcedUnsatisfied;
    return Column(
      children: [
        for (final id in forceableOnboardingSteps) ...[
          if (id != forceableOnboardingSteps.first) const SizedBox(height: 4),
          AppToggleRow(
            title: id,
            value: forced.contains(id),
            onChanged: _catalog.isAvailable(id)
                ? (on) => unawaited(
                    _overrides.forceUnsatisfied(id, forced: on),
                  )
                : null,
          ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: colors.ink3, fontSize: 12)),
        ],
      ),
    );
  }
}
