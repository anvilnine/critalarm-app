import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
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

/// The sound that rings now with a tick, a few built-in sounds, "Yours",
/// and a chip that opens the full sound picker.
///
/// A built-in sound is saved as the default the moment it is tapped, and
/// played once. "Yours" needs the plan that unlocks own sounds: locked, a
/// tap tries it and saves nothing.
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
    return BlocBuilder<PersonalizeCubit, PersonalizeState>(
      builder: (context, state) {
        final cubit = context.read<PersonalizeCubit>();
        final strip = state.soundStrip;
        final current = strip.current;
        final yours = LocaleKeys.personalize_sound_yours.tr();
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
            for (final sound in strip.builtIns) chip(sound, isSelected: false),
            AccessLock(
              feature: AppFeature.ownSounds,
              source: LockSource.personalizeSound,
              name: yours,
              tap: LockTap.tryIt,
              badgeOverhang: PersonalizeStrip.badgeRoom,
              onTry: () => unawaited(cubit.trySound(strip.newestOwn)),
              child: PersonalizeChip(
                key: const ValueKey('sound-yours'),
                label: yours,
                isMarked: isTryingYours,
                onTap: () => switch (yoursTapFor(strip)) {
                  YoursTap.pickNewest => unawaited(
                    cubit.pickSound(strip.newestOwn!),
                  ),
                  YoursTap.openPicker => unawaited(_openPicker(context)),
                },
              ),
            ),
            PersonalizeChip(
              key: const ValueKey('sound-more'),
              label: LocaleKeys.personalize_sound_more.tr(),
              trailing: GlyphType.arrow,
              onTap: () => unawaited(_openPicker(context)),
            ),
          ],
        );
      },
    );
  }
}
