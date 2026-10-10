import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_anchor.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_scope.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_summary.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumbs.dart';
import 'package:critalarm/features/topics/domain/topic_pass_summary.dart';
import 'package:critalarm/features/topics/domain/topic_tokens_page_rules.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Reads the waveform of every bundled sound a topic may ring, so the Sound
/// card draws its real bars on its first frame instead of a flat set that
/// then changes. The Topics list calls it when it opens. A read is made once
/// per launch, and a sound whose bars are known is skipped.
Future<void> warmTopicSoundPeaks() async {
  if (!getIt.isRegistered<AlarmSoundRepository>() ||
      !getIt.isRegistered<SoundPeaksCache>()) {
    return;
  }
  final assignments = getIt<AlarmSoundRepository>().assignmentsNow();
  final wanted = {assignments.defaultSoundId, ...assignments.perTopic.values};
  final cache = getIt<SoundPeaksCache>();
  final sounds = BundledSounds.catalogue(
    platform: defaultTargetPlatform,
    nameOf: (id) => id,
  );
  for (final sound in sounds) {
    if (!wanted.contains(sound.id) || cache.cached(sound.id) != null) continue;
    try {
      await cache.load(sound);
    } on Object catch (_) {
      // The card draws without bars until a later read works.
    }
  }
}

/// The bottom half of the Topic screen: four coloured cards, Look, Sound,
/// Wake-up challenge and Tokens, from the same kit as Personalize.
///
/// Each card says what this topic has now and opens the page that changes it.
/// Look, Sound and Wake-up challenge open their pass page for this topic and
/// the page grows out of the card. Tokens opens the Tokens page with the
/// shell's slide. Every tap opens its page, whatever the plan: a plan word on
/// a card is a tag and never a door to the paywall. That comes on the page,
/// when a locked choice is used.
///
/// An [isExample] topic is not on the server, so it has no Tokens card.
class TopicPassStack extends StatefulWidget {
  const TopicPassStack({
    required this.topicName,
    this.isExample = false,
    super.key,
  });

  final String topicName;
  final bool isExample;

  @override
  State<TopicPassStack> createState() => _TopicPassStackState();
}

class _TopicPassStackState extends State<TopicPassStack> {
  TopicTokensCubit? _tokens;

  bool _areSoundsLoaded = false;
  SoundAssignments _assignments = const SoundAssignments(
    defaultSoundId: BundledSounds.fallbackId,
  );
  List<AlarmSound> _builtIn = const [];
  List<AlarmSound> _userSounds = const [];
  List<AlarmSound> _otherSounds = const [];

  /// The sounds whose peaks were asked for, so each is read once.
  final Set<String> _peaksAsked = {};

  PassScope get _scope => TopicScope(widget.topicName);

  @override
  void initState() {
    super.initState();
    if (!widget.isExample) {
      _tokens = getIt<TopicTokensCubit>();
      unawaited(_tokens!.load(widget.topicName));
    }
    _readSoundsNow();
    unawaited(_loadSounds());
  }

  /// The sound choices are on the device already, so the first frame draws
  /// the sound's name and not an empty value that fills in a moment later.
  /// Only a sound that comes from a downloaded pack is not in these lists, and
  /// it still waits for [_loadSounds].
  void _readSoundsNow() {
    final repository = getIt<AlarmSoundRepository>();
    _assignments = repository.assignmentsNow();
    _userSounds = repository.userSoundsNow();
    _builtIn = BundledSounds.catalogue(
      platform: defaultTargetPlatform,
      nameOf: _nameOfSound,
    );
    _areSoundsLoaded = _holdsRingingSound();
  }

  String _nameOfSound(String id) => 'sound_library.names.$id'.tr();

  /// The sound that rings for the topic, and the default, are both in the
  /// lists read so far.
  bool _holdsRingingSound() {
    final known = {
      for (final sound in [..._builtIn, ..._userSounds]) sound.id,
    };
    return known.containsAll({
      _assignments.soundIdFor(widget.topicName),
      _assignments.defaultSoundId,
    });
  }

  @override
  void didUpdateWidget(TopicPassStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicName != widget.topicName) {
      unawaited(_tokens?.load(widget.topicName));
      unawaited(_loadSounds());
    }
  }

  @override
  void dispose() {
    unawaited(_tokens?.close());
    super.dispose();
  }

  /// The saved sounds and the catalogue, read the way the Personalize page
  /// reads them. Called when the stack builds and again when the Sound page
  /// closes.
  Future<void> _loadSounds() async {
    final repository = getIt<AlarmSoundRepository>();
    final assignments = (await repository.getAssignments()).getOrNull();
    final userSounds = (await repository.getUserSounds()).getOrDefault(
      const [],
    );
    final builtIn = BundledSounds.catalogue(
      platform: defaultTargetPlatform,
      nameOf: _nameOfSound,
    );
    if (!mounted) return;
    final saved =
        assignments ??
        const SoundAssignments(defaultSoundId: BundledSounds.fallbackId);
    setState(() {
      _assignments = saved;
      _userSounds = userSounds;
      _builtIn = builtIn;
      _areSoundsLoaded = _areSoundsLoaded || _holdsRingingSound();
    });
    // Pack sounds are asked of the store's host, which can be slow. They are
    // needed only when the sound that rings is one of them.
    if (_holdsRingingSound()) {
      if (_otherSounds.isNotEmpty) setState(() => _otherSounds = const []);
      return;
    }
    final others = await getIt<SoundPackRepository>().installedSounds(
      nameOf: _nameOfSound,
    );
    if (mounted) {
      setState(() {
        _otherSounds = others;
        _areSoundsLoaded = true;
      });
    }
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

  /// `/` for the Home branch and `/history` for the History branch, the two
  /// bases a topic is reached from.
  String _tokensBase() {
    final path = GoRouterState.of(context).uri.path;
    return path == '/history' || path.startsWith('/history/')
        ? '/history'
        : '/';
  }

  void _open(PassId pass, PassOrigin origin) {
    final router = GoRouter.of(context);
    final Future<Object?> pushed;
    switch (pass) {
      case PassId.look:
        pushed = router.push<Object?>(
          passLocationFor('/look', _scope),
          extra: origin,
        );
      case PassId.sound:
        pushed = router.push<Object?>(
          passLocationFor('/sounds', _scope),
          extra: origin,
        );
      case PassId.challenge:
        pushed = router.push<Object?>(
          passLocationFor('/challenge', _scope),
          extra: origin,
        );
      case PassId.tokens:
        pushed = router.push<Object?>(
          topicTokensPath(_tokensBase(), widget.topicName),
        );
      case PassId.widgets || PassId.appIcon:
        throw UnsupportedError('A topic has no ${pass.name} card');
    }
    // What the page may have changed: the sound and the token count. The look
    // and the challenge redraw from their own change streams.
    unawaited(
      pushed.then((_) {
        if (!mounted) return;
        unawaited(_loadSounds());
        unawaited(_tokens?.load(widget.topicName));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _tokens;
    return PassThumbClock(
      builder: (context, clock) => PassLiveBuilder(
        scope: _scope,
        builder: (context, live) {
          if (cubit == null) return _stack(live, clock, null);
          return BlocBuilder<TopicTokensCubit, TopicTokensState>(
            bloc: cubit,
            builder: (context, state) =>
                _stack(live, clock, state.isReady ? state.tokens.length : null),
          );
        },
      ),
    );
  }

  Widget _stack(
    PassLive live,
    ValueListenable<double> clock,
    int? tokenCount,
  ) {
    final decisions = live.decisions;
    final summary = topicPassSummaryFor(
      topic: widget.topicName,
      isExample: widget.isExample,
      lookNameKey: live.lookStyle.nameKey,
      lookIsStandard: live.lookStyle.id.isFree,
      areSoundsLoaded: _areSoundsLoaded,
      assignments: _assignments,
      builtInSounds: _builtIn,
      userSounds: _userSounds,
      otherSounds: _otherSounds,
      ownSoundsLocked: ownSoundsLockedBy(
        getIt<FeatureAccess>().decide(AppFeature.ownSounds),
      ),
      challengeKind: challengeSavedFor(_scope, getIt<ChallengeChoices>()),
      challengesLocked: decisions[PassId.challenge] is FeatureLocked,
      isPlanRead: live.isPlanRead,
      tokenCount: tokenCount,
    );
    final peaks = _peaksOf(summary.sound);

    WidgetBuilder? thumbOf(PassId pass) {
      final tone = live.toneOf(pass);
      return switch (pass) {
        PassId.look => PassThumbs.look(tone: tone, clock: clock),
        PassId.sound => _anchored(
          PassThumbs.sound(tone: tone, clock: clock, peaks: peaks),
        ),
        PassId.challenge => PassThumbs.challenge(
          tone: tone,
          kind: live.challengeKind,
        ),
        PassId.widgets || PassId.appIcon || PassId.tokens => null,
      };
    }

    final groupLabel = widget.isExample
        ? LocaleKeys.topic_passes_group_label_example.tr()
        : LocaleKeys.topic_passes_group_label.tr();
    return Material(
      type: MaterialType.transparency,
      child: AppPassBands(
        groupLabel: groupLabel,
        cards: [
          for (final item in summary.cards)
            _card(live, item, thumbOf(item.pass)),
        ],
      ),
    );
  }

  /// The Sound card's picture carries the guide's pointer. A card cannot be
  /// wrapped, and the picture is the part of it that always shows.
  WidgetBuilder _anchored(WidgetBuilder inner) =>
      (context) => FeatureGuideAnchor(
        id: FeatureGuideAnchorId.topicSound,
        child: inner(context),
      );

  AppPassCard _card(
    PassLive live,
    TopicPassItem item,
    WidgetBuilder? thumbnail,
  ) {
    final pass = item.pass;
    // The card's label is the pass's plain name. The page says which topic.
    final plain = passLabelFor(pass, const EverywhereScope());
    final label = plain.key.tr();
    final value = switch (item.value) {
      PassValueText(:final text) => text,
      PassValueKey(:final key) => key.tr(),
    };
    final decision = live.decisions[pass];
    final tag = item.hasTag && decision is FeatureLocked
        ? planWordFor(decision.offer)
        : null;
    return AppPassCard(
      key: ValueKey('topic-pass-${pass.name}'),
      pass: pass,
      tone: live.toneOf(pass),
      label: label,
      value: value,
      tag: tag,
      isOn: item.isOn,
      thumbnail: thumbnail,
      semanticLabel: _spokenLabel(label, value, tag),
      semanticHint: LocaleKeys.personalize_passes_root_pass_hint.tr(
        namedArgs: {'label': label},
      ),
      onTap: (origin) => _open(pass, origin),
    );
  }

  String _spokenLabel(String label, String value, String? tag) {
    if (value.isEmpty) return tag == null ? label : '$label, $tag';
    return tag == null
        ? LocaleKeys.personalize_passes_root_pass_label.tr(
            namedArgs: {'label': label, 'value': value},
          )
        : LocaleKeys.personalize_passes_root_pass_label_locked.tr(
            namedArgs: {'label': label, 'value': value, 'plan': tag},
          );
  }
}
