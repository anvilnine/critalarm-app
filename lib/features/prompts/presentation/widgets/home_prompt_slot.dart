import 'package:critalarm/features/permissions/presentation/widgets/setup_health_banner.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_state.dart';
import 'package:critalarm/features/prompts/presentation/widgets/no_server_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pinned slot above the Home stage hosting the single active alert or prompt.
///
/// Smoothly animates cards in with a spring overshoot and collapses on
/// dismissal, enforcing the single-slot invariant.
class HomePromptSlot extends StatelessWidget {
  const HomePromptSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomePromptCubit, HomePromptState>(
      builder: (context, state) {
        final Widget child;

        if (state.isDismissing || state.promptType == HomePromptType.none) {
          child = const SizedBox.shrink(key: ValueKey('empty_prompt'));
        } else {
          switch (state.promptType) {
            case HomePromptType.noServer:
              child = const NoServerPromptCard(key: ValueKey('no_server'));
            case HomePromptType.criticalHealth:
              child = const SetupHealthBanner(key: ValueKey('health_banner'));
            // The backup nudge is not a card up here any more. It is a line
            // pinned above the tab bar, so it never pushes a topic off the
            // screen. Pro is not in this slot at all: it asks as a sheet.
            case HomePromptType.proEnding:
            case HomePromptType.accountBackup:
            case HomePromptType.none:
              child = const SizedBox.shrink(key: ValueKey('empty_prompt'));
          }
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.08),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: child,
          ),
        );
      },
    );
  }
}
