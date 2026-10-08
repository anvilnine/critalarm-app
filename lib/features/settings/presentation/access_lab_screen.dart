import 'dart:async';

import 'package:critalarm/app/access/observed_api_session_store.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/settings/presentation/access_lab_rules.dart';
import 'package:critalarm/features/settings/presentation/developer_options_group.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Developer options > Plans and features. Puts the phone in any plan
/// state with one tap and shows what every feature decides.
///
/// It only writes [DevAccessSwitches]: a state per holding and a server
/// mode. Every answer on it is read back from `Holdings` and
/// `FeatureAccess`, the same two the rest of the app reads. No feature is
/// forced from here.
///
/// The route exists only in a build made with
/// --dart-define=SKIP_PAYWALL=true. The strings are plain English on
/// purpose: it is a developer page and is on the localization skip list.
class AccessLabScreen extends StatefulWidget {
  const AccessLabScreen({super.key});

  /// The flag the app writes next to the alarm sound choices for the
  /// native side. Read by its key, because the code that writes it may not
  /// be in this build.
  static const ownSoundsLockedKey = 'alarm_sound_own_locked';

  @override
  State<AccessLabScreen> createState() => _AccessLabScreenState();
}

class _AccessLabScreenState extends State<AccessLabScreen> {
  final _subscriptions = <StreamSubscription<Object?>>[];
  Listenable? _listened;
  Timer? _later;

  @override
  void initState() {
    super.initState();
    if (!getIt.isRegistered<DevAccessSwitches>()) return;
    _subscriptions
      ..add(getIt<Holdings>().stream.listen((_) => _changed()))
      ..add(getIt<FeatureAccess>().changes.listen((_) => _changed()));
    _listened = Listenable.merge([
      getIt<DevAccessSwitches>(),
      getIt<ObservedApiSessionStore>().mode,
    ])..addListener(_changed);
  }

  @override
  void dispose() {
    _later?.cancel();
    _listened?.removeListener(_changed);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  /// Draws again now, and once more after the widget snapshot has had time
  /// to be written: that write waits half a second and tells nobody.
  void _changed() {
    if (!mounted) return;
    setState(() {});
    _later?.cancel();
    _later = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() {});
    });
  }

  void _open(AccessLabJump jump) {
    if (jump.isTab) {
      context.go(jump.location);
    } else {
      unawaited(context.push(jump.location));
    }
  }

  void _openPaywall(Holding holding) {
    switch (holding) {
      case Holding.hosted:
        unawaited(context.push(hostedPaywallLocation(PaywallSource.direct)));
      case Holding.pro:
        unawaited(openProPaywall(context, ProPackSheetSource.direct));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: 'Plans and features',
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings/developer');
            }
          },
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
            child: AppSheet(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: getIt.isRegistered<DevAccessSwitches>()
                  ? _body(context)
                  : const AppNote(text: 'This build has no plan switches.'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final switches = getIt<DevAccessSwitches>();
    final holdings = getIt<Holdings>();
    final access = getIt<FeatureAccess>();
    final sources = getIt<List<OverriddenHoldingSource>>();
    final serverMode = getIt<OverriddenServerMode>();
    final forcedLine = accessLabForcedLine(
      forced: {
        for (final holding in Holding.values)
          holding: switches.forcedState(holding),
      },
      serverMode: switches.serverMode,
    );
    final preset = switches.preset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        AppNote(text: forcedLine ?? 'Real: nothing is forced.'),
        DeveloperOptionsGroup(
          title: 'Presets',
          rows: [
            // Two to a line, so the seven fit above the fold.
            for (var i = 0; i < AccessPreset.values.length; i += 2)
              Row(
                children: [
                  for (final choice in AccessPreset.values.skip(i).take(2))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AppButton(
                          label: choice.label,
                          size: AppButtonSize.sm,
                          variant: choice == preset
                              ? AppButtonVariant.ink
                              : AppButtonVariant.ghost,
                          onPressed: () => unawaited(switches.apply(choice)),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        DeveloperOptionsGroup(
          title: 'Holdings',
          rows: [
            for (final source in sources)
              _Choice<HoldingState?>(
                title: accessLabHoldingName(source.holding),
                line: accessLabHoldingLine(
                  seen: holdings.stateOf(source.holding),
                  real: source.realState,
                ),
                items: const [null, ...HoldingState.values],
                selected: switches.forcedState(source.holding),
                label: accessLabStateChoiceText,
                onChanged: (state) =>
                    unawaited(switches.force(source.holding, state)),
              ),
          ],
        ),
        DeveloperOptionsGroup(
          title: 'Server',
          rows: [
            _Choice<ServerModeChoice>(
              title: 'Server mode',
              line:
                  'App sees ${accessLabServerModeText(access.serverMode)}. '
                  'Saved session says '
                  '${accessLabServerModeText(serverMode.realValue)}.',
              items: ServerModeChoice.values,
              selected: switches.serverMode,
              label: accessLabServerChoiceText,
              onChanged: (choice) => unawaited(switches.setServerMode(choice)),
            ),
          ],
        ),
        DeveloperOptionsGroup(
          title: 'Features',
          rows: [
            // Built from the table, in table order: a feature added there
            // gets a row here with no edit to this screen.
            for (final feature in featureTable.keys)
              _featureRow(feature, access),
          ],
        ),
        DeveloperOptionsGroup(
          title: 'Pages that show several features',
          rows: [
            for (final page in accessLabPages)
              AppValueRow(title: page.label, onTap: () => _open(page)),
          ],
        ),
        DeveloperOptionsGroup(
          title: 'What native was told',
          rows: [
            AppValueRow(
              title: 'Widget snapshot: locked',
              value: _widgetLockedText(),
              glyph: GlyphType.info,
            ),
            AppValueRow(
              title: AccessLabScreen.ownSoundsLockedKey,
              value: _ownSoundsLockedText(),
              glyph: GlyphType.info,
            ),
            AppValueRow(
              title: 'Rewrite the widget snapshot now',
              onTap: () {
                getIt<WidgetSync>().rewrite();
                _changed();
              },
            ),
          ],
        ),
        DeveloperOptionsGroup(
          title: 'Paywalls',
          rows: [
            for (final holding in Holding.values)
              AppValueRow(
                title: 'Open the ${accessLabHoldingName(holding)} paywall',
                onTap: () => _openPaywall(holding),
              ),
          ],
        ),
      ],
    );
  }

  Widget _featureRow(AppFeature feature, FeatureAccess access) {
    final jump = accessLabJumps[feature];
    return AppValueRow(
      title: accessLabFeatureName(feature),
      value: accessLabDecisionText(access.decide(feature)),
      detail:
          '${accessLabRuleText(featureTable[feature])}. '
          '${accessLabJumpText(feature)}.',
      glyph: jump == null ? GlyphType.minus : GlyphType.arrow,
      onTap: jump == null ? null : () => _open(jump),
    );
  }

  String _widgetLockedText() {
    final sync = getIt<WidgetSync>();
    final locked = sync.lastWrittenLocked;
    if (locked == null) return 'not written this run';
    final at = sync.lastWrittenAt;
    final time = at == null
        ? ''
        : ' at ${TimeOfDay.fromDateTime(at).format(context)}';
    return '$locked$time';
  }

  String _ownSoundsLockedText() {
    final prefs = getIt<SharedPreferences>();
    const key = AccessLabScreen.ownSoundsLockedKey;
    return prefs.containsKey(key) ? '${prefs.get(key)}' : 'not written yet';
  }
}

/// One control of the lab: a name, a line that says what is true now, and
/// the choices side by side.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.line,
    required this.items,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final String line;
  final List<T> items;
  final T selected;
  final String Function(T item) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTypography.small(colors.ink)),
          const SizedBox(height: 2),
          Text(line, style: AppTypography.small(colors.ink3, fontSize: 12)),
          const SizedBox(height: 8),
          AppSegmentedControl<T>(
            items: items,
            selectedItem: selected,
            labelBuilder: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
