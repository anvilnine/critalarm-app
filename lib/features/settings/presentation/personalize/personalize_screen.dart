import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumbs.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Personalize: a stack of five coloured cards, Look, Sound, Wake-up
/// challenge, Widgets and App icon.
///
/// Each card shows what is set now and one thumbnail. A tap grows the card
/// into the pass's own page. Every tap opens its page, whatever the plan: a
/// plan word on a card is a tag and never a door to the paywall. A pass this
/// phone cannot use (widgets on the web, the icon where it cannot change) is
/// left out.
///
/// The page sets the defaults for the phone and saves to the same places the
/// older Settings rows do.
class PersonalizeScreen extends StatelessWidget {
  const PersonalizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<PersonalizeCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _PersonalizeView(),
    );
  }
}

class _PersonalizeView extends StatefulWidget {
  const _PersonalizeView();

  @override
  State<_PersonalizeView> createState() => _PersonalizeViewState();
}

class _PersonalizeViewState extends State<_PersonalizeView> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  StreamSubscription<AppFeature>? _ownSoundChanges;
  AppIcon? _icon;

  /// The sounds whose peaks were asked for, so each is read once.
  final Set<String> _peaksAsked = {};

  @override
  void initState() {
    super.initState();
    // The sound that rings follows the lock on own sounds.
    _ownSoundChanges = _access.changes
        .where((feature) => feature == AppFeature.ownSounds)
        .listen((_) {
          if (mounted) setState(() {});
        });
    unawaited(_readIcon());
  }

  @override
  void dispose() {
    unawaited(_ownSoundChanges?.cancel());
    super.dispose();
  }

  Future<void> _readIcon() async {
    final icon = await getIt<AppIconHost>().current();
    if (mounted) setState(() => _icon = icon);
  }

  /// What the pages may have changed: the sound and the icon.
  Future<void> _reload() async {
    if (!mounted) return;
    await context.read<PersonalizeCubit>().load();
    await _readIcon();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  void _open(PassId pass, PassOrigin origin) {
    final name = switch (pass) {
      PassId.look => AppRoute.personalizeLook,
      PassId.sound => AppRoute.soundPicker,
      PassId.challenge => AppRoute.personalizeChallenge,
      PassId.widgets => AppRoute.personalizeWidgets,
      PassId.appIcon => AppRoute.appIcon,
    };
    unawaited(
      context.pushNamed<void>(name, extra: origin).then((_) => _reload()),
    );
  }

  /// The loudness of [sound] if it is known. Asks for it once if it is not,
  /// and redraws when it arrives.
  List<double>? _peaksOf(AlarmSound? sound) {
    if (sound == null) return null;
    final own = sound.peaks;
    if (own != null && own.isNotEmpty) return own;
    final cache = getIt<SoundPeaksCache>();
    final cached = cache.cached(sound.id);
    if (cached != null) return cached;
    if (_peaksAsked.add(sound.id)) {
      unawaited(
        cache.load(sound).then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersonalizeCubit, PersonalizeState>(
      builder: (context, state) {
        final sound = state
            .soundStrip(
              ownSoundsLocked: ownSoundsLockedBy(
                _access.decide(AppFeature.ownSounds),
              ),
            )
            .current;
        final peaks = _peaksOf(sound);
        return PassThumbClock(
          builder: (context, clock) => PassLiveBuilder(
            soundName: sound?.name,
            appIcon: _icon,
            builder: (context, live) {
              WidgetBuilder thumbOf(PassId pass) {
                final tone = live.toneOf(pass);
                return switch (pass) {
                  PassId.look => PassThumbs.look(tone: tone, clock: clock),
                  PassId.sound => PassThumbs.sound(
                    tone: tone,
                    clock: clock,
                    peaks: peaks,
                  ),
                  PassId.challenge => PassThumbs.challenge(
                    tone: tone,
                    kind: live.challengeKind,
                  ),
                  PassId.widgets => PassThumbs.widgets(),
                  PassId.appIcon => PassThumbs.appIcon(
                    _icon ?? AppIcon.standard,
                  ),
                };
              }

              return Material(
                type: MaterialType.transparency,
                child: AppPassStack(
                  title: LocaleKeys.personalize_title.tr(),
                  backLabel: LocaleKeys.personalize_passes_root_back_label.tr(),
                  groupLabel: LocaleKeys.personalize_passes_root_stack_label
                      .tr(),
                  onBack: _close,
                  cards: [
                    for (final item in live.summary.present)
                      _card(live, item.pass, thumbOf(item.pass)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  AppPassCard _card(PassLive live, PassId pass, WidgetBuilder thumbnail) {
    final label = live.labelOf(pass);
    final value = live.valueOf(pass);
    final tag = live.tagOf(pass);
    return AppPassCard(
      key: ValueKey('pass-${pass.name}'),
      pass: pass,
      tone: live.toneOf(pass),
      label: label,
      value: value,
      tag: tag,
      isOn: live.isOn(pass),
      thumbnail: thumbnail,
      semanticLabel: tag == null
          ? LocaleKeys.personalize_passes_root_pass_label.tr(
              namedArgs: {'label': label, 'value': value},
            )
          : LocaleKeys.personalize_passes_root_pass_label_locked.tr(
              namedArgs: {'label': label, 'value': value, 'plan': tag},
            ),
      semanticHint: LocaleKeys.personalize_passes_root_pass_hint.tr(
        namedArgs: {'label': label},
      ),
      onTap: (origin) => _open(pass, origin),
    );
  }
}
