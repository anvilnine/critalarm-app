import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:flutter/foundation.dart';

/// What the `hook_up` step opens with.
enum HookUpLead {
  /// The curl line.
  curl,

  /// The steps for the tool saved on the topic.
  toolSteps,
}

/// What the offer sequence opens on.
enum OfferLead {
  /// Every server can wake you.
  topics,

  /// Know it still reaches you.
  weeklyCheck,

  /// See it from your home screen.
  widgets,

  /// The order the paywall uses without an answer.
  today,
}

/// The line Home shows while it waits for the first message.
enum SetupWaitingLine {
  sendFirstLine,
  fromYourServer,
  runTheJob,
  uptimeKuma,
  homeAssistant,
  healthchecks,
}

/// Everything one answer changes, as data.
@immutable
class SetupUseProfile {
  const SetupUseProfile({
    required this.name,
    required this.otherNames,
    required this.toolOrder,
    required this.selectedTool,
    required this.sampleKey,
    required this.hookUpLead,
    required this.offerLead,
    required this.waitingLine,
  });

  /// The topic name the first topic arrives with, or null for none.
  final String? name;

  /// The name chips under the field.
  final List<String> otherNames;

  /// The tool chips, left to right. Every tool except
  /// [ToolTemplate.other], once.
  final List<ToolTemplate> toolOrder;

  /// The tool that starts selected, or null for none.
  final ToolTemplate? selectedTool;

  /// The `en.json` key of the sample message of the first real alarm, or
  /// null to leave the server's own text.
  final String? sampleKey;

  final HookUpLead hookUpLead;
  final OfferLead offerLead;
  final SetupWaitingLine waitingLine;

  /// The profile of [use].
  static SetupUseProfile of(SetupUse use) => _profiles[use]!;

  static const _profiles = <SetupUse, SetupUseProfile>{
    SetupUse.servers: SetupUseProfile(
      name: 'prod-db', // l10n-ok: topic name
      otherNames: [
        'prod-api', // l10n-ok: topic name
        'client-vps', // l10n-ok: topic name
        'deploy-failed', // l10n-ok: topic name
      ],
      toolOrder: [
        ToolTemplate.curl,
        ToolTemplate.cron,
        ToolTemplate.ci,
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.homeAssistant,
      ],
      selectedTool: ToolTemplate.curl,
      sampleKey: 'setup_use.sample.servers',
      hookUpLead: HookUpLead.curl,
      offerLead: OfferLead.topics,
      waitingLine: SetupWaitingLine.fromYourServer,
    ),
    SetupUse.homelab: SetupUseProfile(
      name: 'uptime-kuma', // l10n-ok: topic name
      otherNames: [
        'homelab', // l10n-ok: topic name
        'nas-disk', // l10n-ok: topic name
        'backup-job', // l10n-ok: topic name
      ],
      toolOrder: [
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.homeAssistant,
        ToolTemplate.cron,
        ToolTemplate.ci,
        ToolTemplate.curl,
      ],
      selectedTool: ToolTemplate.uptimeKuma,
      sampleKey: 'setup_use.sample.homelab',
      hookUpLead: HookUpLead.toolSteps,
      offerLead: OfferLead.weeklyCheck,
      waitingLine: SetupWaitingLine.uptimeKuma,
    ),
    SetupUse.jobs: SetupUseProfile(
      name: 'nightly-backup', // l10n-ok: topic name
      otherNames: [
        'ci', // l10n-ok: topic name
        'deploy', // l10n-ok: topic name
        'cron', // l10n-ok: topic name
      ],
      toolOrder: [
        ToolTemplate.ci,
        ToolTemplate.cron,
        ToolTemplate.healthchecks,
        ToolTemplate.curl,
        ToolTemplate.uptimeKuma,
        ToolTemplate.homeAssistant,
      ],
      selectedTool: ToolTemplate.ci,
      sampleKey: 'setup_use.sample.jobs',
      hookUpLead: HookUpLead.curl,
      offerLead: OfferLead.weeklyCheck,
      waitingLine: SetupWaitingLine.runTheJob,
    ),
    SetupUse.home: SetupUseProfile(
      name: 'home-assistant', // l10n-ok: topic name
      otherNames: [
        'freezer', // l10n-ok: topic name
        'garage-door', // l10n-ok: topic name
        'washer', // l10n-ok: topic name
      ],
      toolOrder: [
        ToolTemplate.homeAssistant,
        ToolTemplate.curl,
        ToolTemplate.cron,
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.ci,
      ],
      selectedTool: ToolTemplate.homeAssistant,
      sampleKey: 'setup_use.sample.home',
      hookUpLead: HookUpLead.toolSteps,
      offerLead: OfferLead.widgets,
      waitingLine: SetupWaitingLine.homeAssistant,
    ),
    SetupUse.other: SetupUseProfile(
      name: null,
      otherNames: [],
      toolOrder: [
        ToolTemplate.uptimeKuma,
        ToolTemplate.healthchecks,
        ToolTemplate.homeAssistant,
        ToolTemplate.cron,
        ToolTemplate.ci,
        ToolTemplate.curl,
      ],
      selectedTool: null,
      sampleKey: null,
      hookUpLead: HookUpLead.curl,
      offerLead: OfferLead.today,
      waitingLine: SetupWaitingLine.sendFirstLine,
    ),
  };
}

/// The answer to use: a missing one reads as [SetupUse.other].
SetupUse effectiveUse(SetupUse? saved) => saved ?? SetupUse.other;

/// The tool chips for [use], in order.
List<ToolTemplate> toolOrderFor(SetupUse? use) =>
    SetupUseProfile.of(effectiveUse(use)).toolOrder;

/// The line Home shows while it waits for the first message.
///
/// A saved tool with documented steps wins with its own line. Any other
/// tool, or none, leaves the answer's line.
SetupWaitingLine waitingLineFor({SetupUse? use, ToolTemplate? savedTool}) =>
    switch (savedTool) {
      ToolTemplate.uptimeKuma => SetupWaitingLine.uptimeKuma,
      ToolTemplate.homeAssistant => SetupWaitingLine.homeAssistant,
      ToolTemplate.healthchecks => SetupWaitingLine.healthchecks,
      _ => SetupUseProfile.of(effectiveUse(use)).waitingLine,
    };
