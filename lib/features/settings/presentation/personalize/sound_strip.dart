import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_chip.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Sound section of the Personalize page.
Widget buildPersonalizeSoundStrip(BuildContext context) =>
    const PersonalizeSoundStrip();

/// The sound that rings now with a tick, "Yours", a few built-in sounds,
/// and a chip that opens the full sound picker.
///
/// A built-in sound is saved as the default the moment it is tapped, and
/// played once. "Yours" needs the plan that unlocks own sounds. Locked, a
/// tap plays the person's own sound as a try and saves nothing, or opens
/// the paywall when the phone has no own sound to play.
class PersonalizeSoundStrip extends StatelessWidget {
  const PersonalizeSoundStrip({super.key});

  /// Opens the full picker and reads the choice again when it closes, so
  /// a sound picked there shows here.
  static Future<void> _openPicker(BuildContext context) async {
    final cubit = context.read<PersonalizeCubit>();
    await cubit.stopPlaying();
    if (!context.mounted) return;
    await context.push('/sounds');
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final access = getIt<FeatureAccess>();
    // The order of the chips follows the lock, so the strip is built again
    // when the answer for own sounds changes.
    return StreamBuilder<AppFeature>(
      stream: access.changes.where(
        (feature) => feature == AppFeature.ownSounds,
      ),
      builder: (context, _) => BlocBuilder<PersonalizeCubit, PersonalizeState>(
        builder: (context, state) {
          final cubit = context.read<PersonalizeCubit>();
          final strip = state.soundStrip(
            ownSoundsLocked: ownSoundsLockedBy(
              access.decide(AppFeature.ownSounds),
            ),
          );
          final current = strip.current;
          final yours = strip.yours;
          final yoursLabel = LocaleKeys.personalize_sound_yours.tr();
          final isTryingYours = state.tried?.feature == AppFeature.ownSounds;

          Widget chip(AlarmSound sound, {required bool isSelected}) =>
              PersonalizeChip(
                key: ValueKey('sound-${sound.id}'),
                label: sound.name,
                isSelected: isSelected,
                onTap: () => unawaited(cubit.pickSound(sound)),
              );

          return PersonalizeStrip(
            children: [
              if (current != null) chip(current, isSelected: true),
              AccessLock(
                feature: AppFeature.ownSounds,
                source: LockSource.personalizeSound,
                name: yoursLabel,
                // A try plays the person's own sound. With none on the
                // phone there is nothing to try, so the chip sells.
                tap: yoursCanBeTried(strip) ? LockTap.tryIt : LockTap.sell,
                onTry: yours == null
                    ? null
                    : () => unawaited(cubit.trySound(yours)),
                badgeOverhang: PersonalizeStrip.badgeRoom,
                child: PersonalizeChip(
                  key: const ValueKey('sound-yours'),
                  label: yoursLabel,
                  isMarked: isTryingYours,
                  onTap: () => switch (yoursTapFor(strip)) {
                    YoursTap.pick => unawaited(cubit.pickSound(yours!)),
                    YoursTap.openPicker => unawaited(_openPicker(context)),
                  },
                ),
              ),
              for (final sound in strip.builtIns)
                chip(sound, isSelected: false),
              PersonalizeChip(
                key: const ValueKey('sound-more'),
                label: LocaleKeys.personalize_sound_more.tr(),
                trailing: GlyphType.arrow,
                onTap: () => unawaited(_openPicker(context)),
              ),
            ],
          );
        },
      ),
    );
  }
}
