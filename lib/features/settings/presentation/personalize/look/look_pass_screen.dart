import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/look_deck_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/look/look_action_bar.dart';
import 'package:critalarm/features/settings/presentation/personalize/look/look_deck.dart';
import 'package:critalarm/features/settings/presentation/personalize/look/look_phone.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_look_flow.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/look_pass_tone.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumbs.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Look page: a deck of phones, one per alarm look.
///
/// The page takes the colour of the look in the middle of the deck. It opens
/// in the colour of the look in use, fades from one look's colour to the next
/// while the deck is dragged, and keeps its header readable on the way. The
/// bottom action follows the look in the middle: a status for the look in use,
/// a button for an open one, and for a locked one the try bar, because
/// swiping to a locked look is the try and nothing is saved by it.
///
/// A tag never opens a paywall here. A locked look is drawn as the real thing.
/// The paywall opens only from the act that uses a locked look, and the lock
/// rule (`lockTapFor`, through `keepOrOpenPaywall`) says so.
class LookPassScreen extends StatelessWidget {
  const LookPassScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<PersonalizeCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    // The rock of the middle phone runs on one clock that stops while the
    // route is covered and holds still under reduce motion.
    child: PassThumbClock(
      builder: (context, clock) => PassLiveBuilder(
        builder: (context, live) => _LookPage(live: live, clock: clock),
      ),
    ),
  );
}

class _LookPage extends StatefulWidget {
  const _LookPage({required this.live, required this.clock});

  final PassLive live;
  final ValueListenable<double> clock;

  @override
  State<_LookPage> createState() => _LookPageState();
}

class _LookPageState extends State<_LookPage> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  late final List<AlarmStyleId> _deck = lookDeckFor(
    alarmStyles.map((style) => style.id),
  );

  late final ValueNotifier<double> _page;
  late final ValueNotifier<int> _settled;
  late final ValueNotifier<int> _centred;

  /// One ambient profile per settled ground: a new object on each build would
  /// ask the canvas to retint again and again.
  AmbientProfile? _profile;
  Color? _profileGround;

  @override
  void initState() {
    super.initState();
    final start = initialDeckPage(_deck, widget.live.lookStyle.id);
    _page = ValueNotifier<double>(start.toDouble());
    _settled = ValueNotifier<int>(start);
    _centred = ValueNotifier<int>(start);
  }

  @override
  void dispose() {
    _page.dispose();
    _settled.dispose();
    _centred.dispose();
    super.dispose();
  }

  OwnLookPhase get _ownPhase {
    final keeper = getIt<OwnAlarmLookKeeper>();
    if (keeper.isReady) return OwnLookPhase.held;
    return keeper.hasPhoto ? OwnLookPhase.saved : OwnLookPhase.none;
  }

  FeatureDecision get _decision => _access.decide(AppFeature.alarmScreenStyles);

  LookFade _fadeFor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = context.appColors;
    final tones = [
      for (final id in _deck)
        lookPassToneFor(lookStyleFor(id), brightness, colors),
    ];
    return LookFade(
      grounds: [for (final tone in tones) tone.ground],
      texts: [for (final tone in tones) tone.onGround],
      ink: colors.inkFixed,
      cream: colors.onPanel,
    );
  }

  LookAction _actionFor(int centred) => lookActionFor(
    centred: _deck[centred],
    inUse: widget.live.lookStyle.id,
    decision: _decision,
    isPlanRead: _access.isPlanRead,
    own: _ownPhase,
  );

  /// The tap that uses or keeps the look in the middle. Using a look is the
  /// act, so it is the only place a locked look reaches the paywall. The
  /// lock rule decides: it waits for the plan to be read, says go for an open
  /// look and opens the paywall for a locked one.
  Future<void> _keep() async {
    final id = _deck[_centred.value];
    final action = _actionFor(_centred.value);
    switch (action.control) {
      case LookControl.inUse:
        return;
      case LookControl.addPhoto:
        // The photo flow asks the same rule before it picks anything.
        await addOwnPhoto(context);
      case LookControl.use:
        final go =
            id.isFree ||
            await keepOrOpenPaywall(
              context,
              AppFeature.alarmScreenStyles,
              LockSource.personalizeLook,
            );
        if (!go || !mounted) return;
        AppHaptics.selection();
        await getIt<AlarmStyleChoices>().setDefault(id.id);
    }
  }

  void _openPreview(AlarmStyleId id) {
    // Yours has a picture to show only while its photo is held.
    if (id == AlarmStyleId.own && _ownPhase != OwnLookPhase.held) return;
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        RingingPreviewPage.route(style: lookStyleFor(id)),
      ),
    );
  }

  /// A tap on the phone that is already in the middle. A fixed look and a
  /// held photo open the full-screen preview. Yours with nothing to draw
  /// has nothing to preview, so its tap is the button under it.
  void _tapCentred(AlarmStyleId id) {
    if (id == AlarmStyleId.own && _ownPhase == OwnLookPhase.none) {
      unawaited(_keep());
      return;
    }
    _openPreview(id);
  }

  void _openOwnSheet() => unawaited(
    showOwnLookSheet(context, canEdit: _ownPhase == OwnLookPhase.held),
  );

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final fade = _fadeFor(context);
    final media = MediaQuery.of(context);
    // On a short display the deck and the action sit side by side under the
    // header, so the action is in view without a bar taking the height. On
    // any other display the action is pinned under the page, at every text
    // size, so a person can always reach it.
    final isShort = media.size.height < AppSize.shortMaxHeight;
    final own = _ownPhase;

    final deck = SliverLayoutBuilder(
      builder: (context, constraints) {
        // The deck takes what the header leaves, and no less than it needs:
        // a short display or large text scrolls the page.
        final room = constraints.remainingPaintExtent - 24;
        final height = math.max(
          isShort ? _minShortDeckHeight : _minDeckHeight,
          room,
        );
        final lookDeck = LookDeck(
          deck: _deck,
          fade: fade,
          page: _page,
          settled: _settled,
          centred: _centred,
          clock: widget.clock,
          inUse: live.lookStyle.id,
          own: own,
          height: height,
          onTapCentred: _tapCentred,
          onOwnCorner: _openOwnSheet,
        );
        return SliverToBoxAdapter(
          child: SizedBox(
            height: height,
            child: isShort
                ? Row(
                    children: [
                      SizedBox(
                        width: _sideWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(child: _bar(fade)),
                        ),
                      ),
                      Expanded(child: lookDeck),
                    ],
                  )
                : lookDeck,
          ),
        );
      },
    );

    // The page paints the lerp itself. The canvas under it follows only when
    // the deck settles, so it does not fight the fade.
    return ValueListenableBuilder<int>(
      valueListenable: _settled,
      builder: (context, settled, _) => AmbientOverride(
        profile: _profileFor(fade.groundAt(settled.toDouble())),
        // The page below keeps its own override to itself: it changes on
        // every frame of a drag. A scope with no controller takes it.
        child: AmbientScope(
          isActive: AmbientScope.isInAmbientScope(context),
          child: ListenableBuilder(
            listenable: Listenable.merge([_page, _settled]),
            builder: (context, _) {
              final centred = _centred.value;
              final page = context.reduceMotion
                  ? _settled.value.toDouble()
                  : _page.value;
              final tone = PassTone(
                ground: fade.groundAt(page),
                onGround: fade.textAt(page),
              );
              return AppPassPage(
                tone: tone,
                label: live.labelOf(PassId.look),
                value: lookNameOf(_deck[centred]),
                tag: live.tagOf(PassId.look),
                trailing: _PlayPill(tone: tone),
                slivers: [deck],
                bottomBar: isShort ? null : _bar(fade),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bar(LookFade fade) => ValueListenableBuilder<int>(
    valueListenable: _centred,
    builder: (context, centred, _) {
      final decision = _decision;
      final action = _actionFor(centred);
      final hint = lookHintFor(
        action: action,
        decision: decision,
        isPlanRead: _access.isPlanRead,
        deck: _deck,
      );
      return LookActionBar(
        action: action,
        hint: hint.lockedCount == null
            ? hint.key.tr()
            : hint.key.tr(
                namedArgs: {
                  'count': '${hint.lockedCount}',
                  'plan': planWordFor(
                    decision is FeatureLocked ? decision.offer : Holding.pro,
                  ),
                },
              ),
        confirming: decision is FeatureConfirming ? decision.holding : null,
        fade: fade,
        page: _page,
        onKeep: () => unawaited(_keep()),
      );
    },
  );

  AmbientProfile _profileFor(Color ground) {
    if (_profile == null || _profileGround != ground) {
      _profileGround = ground;
      _profile = AmbientAppProfiles.passGround(ground);
    }
    return _profile!;
  }

  /// The least room the deck is given before the page scrolls instead.
  static const double _minDeckHeight = 330;

  /// The same on a short display, where the page scrolls by little.
  static const double _minShortDeckHeight = 200;

  /// The width of the column that holds the action on a short display.
  static const double _sideWidth = 232;
}

/// Play, at the right of the pinned top row: it plays the ring sound and stops
/// it, through the page's cubit, as the old preview's button did.
class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.tone});

  final PassTone tone;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PersonalizeCubit, PersonalizeState>(
        buildWhen: (a, b) => a.isPlaying != b.isPlaying,
        builder: (context, state) {
          final cubit = context.read<PersonalizeCubit>();
          final isPlaying = state.isPlaying;
          Future<void> toggle() async {
            AppHaptics.selection();
            // Asked once the plan is read, so right after a cold start a Pro
            // holder hears their own sound and not its stand-in.
            final access = getIt<FeatureAccess>();
            final ownSounds = await ownSoundsOnceReady(access);
            await cubit.togglePlay(
              ownSoundsLocked: ownSoundsLockedBy(ownSounds),
            );
          }

          final capped = MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: kChromeMaxTextScale);
          return Semantics(
            button: true,
            label: isPlaying
                ? LocaleKeys.sound_picker_stop_aria_label.tr()
                : LocaleKeys.personalize_play_label.tr(),
            excludeSemantics: true,
            onTap: () => unawaited(toggle()),
            child: GestureDetector(
              key: const ValueKey('look-play'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(toggle()),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: capped),
                child: Container(
                  height: kPassRingSize,
                  padding: const EdgeInsetsDirectional.only(
                    start: 14,
                    end: 18,
                  ),
                  decoration: BoxDecoration(
                    color: tone.onGround,
                    borderRadius: BorderRadius.circular(kPassRingSize / 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppGlyph(
                        isPlaying ? GlyphType.stop : GlyphType.play,
                        size: 15,
                        color: tone.ground,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isPlaying
                            ? LocaleKeys.personalize_passes_look_stop.tr()
                            : LocaleKeys.personalize_passes_look_play.tr(),
                        style: AppTypography.body(tone.ground).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
