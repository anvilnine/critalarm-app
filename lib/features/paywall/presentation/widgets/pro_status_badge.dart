import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Pro badge, shown only while the account is on Pro. Takes no space
/// otherwise.
class ProStatusBadge extends StatelessWidget {
  const ProStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProStatusCubit>(),
      child: BlocBuilder<ProStatusCubit, bool>(
        builder: (context, isPro) => AnimatedSwitcher(
          duration: AppDurations.base,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: isPro
              ? ProBadge(label: LocaleKeys.paywall_pro_badge.tr())
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
