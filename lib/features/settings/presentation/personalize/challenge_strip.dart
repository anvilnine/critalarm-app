import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge_chip_picture.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_chip.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Challenge section of the Personalize page.
Widget buildPersonalizeChallengeStrip(BuildContext context) =>
    const PersonalizeChallengeStrip();

/// The challenge the page shows in its preview frame, or null when it
/// shows the ringing alarm.
Challenge? challengeShownBy(PersonalizeState state) {
  final tried = state.tried;
  if (tried == null || tried.feature != AppFeature.wakeUpChallenges) {
    return null;
  }
  return challengeOf(ChallengeKind.fromId(tried.optionId));
}

/// "Off", then every challenge this build has.
///
/// The tick is on what a topic made on this phone starts with. Open, a tap
/// on a challenge saves it as that and shows it in the preview. Locked, a
/// tap shows it in the preview as a try and saves nothing, and the tick
/// stays on Off, because no challenge runs without the plan. "Off" is free
/// and ends a try.
///
/// The choice here is for topics made from now on. A topic that exists
/// keeps what its own page says.
class PersonalizeChallengeStrip extends StatefulWidget {
  const PersonalizeChallengeStrip({super.key});

  @override
  State<PersonalizeChallengeStrip> createState() =>
      _PersonalizeChallengeStripState();
}

class _PersonalizeChallengeStripState extends State<PersonalizeChallengeStrip> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  late final ChallengeChoices _choices = getIt<ChallengeChoices>();
  StreamSubscription<Object?>? _accessChanges;
  StreamSubscription<void>? _choiceChanges;

  @override
  void initState() {
    super.initState();
    _accessChanges = _access.changes
        .where((feature) => feature == AppFeature.wakeUpChallenges)
        .listen((_) => _redraw());
    _choiceChanges = _choices.changes.listen((_) => _redraw());
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_accessChanges?.cancel());
    unawaited(_choiceChanges?.cancel());
    super.dispose();
  }

  void _show(Challenge challenge) => context.read<PersonalizeCubit>().tryOption(
    PersonalizeTry(AppFeature.wakeUpChallenges, optionId: challenge.kind.id),
  );

  Future<void> _pick(Challenge challenge) async {
    // Saved only once the plan is read and is not a lock. A tap that lands
    // on a lock drawn late is a try and saves nothing.
    await _access.ready;
    if (!mounted) return;
    if (_access.decide(AppFeature.wakeUpChallenges) is! FeatureLocked) {
      await _choices.setDefaultForNewTopics(challenge.kind);
      if (!mounted) return;
    }
    _show(challenge);
  }

  Future<void> _pickOff() async {
    context.read<PersonalizeCubit>().clearTry();
    await _choices.setDefaultForNewTopics(null);
  }

  @override
  Widget build(BuildContext context) {
    final isLocked =
        _access.decide(AppFeature.wakeUpChallenges) is FeatureLocked;
    final saved = isLocked ? null : challengeOf(_choices.defaultForNewTopics);
    return BlocBuilder<PersonalizeCubit, PersonalizeState>(
      builder: (context, state) {
        final shown = challengeShownBy(state);
        return PersonalizeStrip(
          children: [
            PersonalizeChip(
              key: const ValueKey('challenge-off'),
              label: LocaleKeys.challenges_off.tr(),
              isSelected: saved == null,
              onTap: () => unawaited(_pickOff()),
            ),
            for (final challenge in challenges)
              AccessLock(
                feature: AppFeature.wakeUpChallenges,
                source: LockSource.personalizeChallenge,
                name: challenge.nameKey.tr(),
                tap: LockTap.tryIt,
                onTry: () => _show(challenge),
                badgeSeat: FeatureLockSeat.above,
                badgeOverhang: PersonalizeStrip.badgeOverhang,
                child: PersonalizeChip(
                  key: ValueKey('challenge-${challenge.kind.id}'),
                  // A picture and one word. The full name is what a
                  // screen reader says.
                  label: challengeChipWordKey(challenge.kind).tr(),
                  spokenLabel: challenge.nameKey.tr(),
                  picture: (color) => ChallengeChipPicture(
                    kind: challenge.kind,
                    color: color,
                  ),
                  isSelected: saved?.kind == challenge.kind,
                  isMarked:
                      shown?.kind == challenge.kind &&
                      saved?.kind != challenge.kind,
                  onTap: () => unawaited(_pick(challenge)),
                ),
              ),
          ],
        );
      },
    );
  }
}
