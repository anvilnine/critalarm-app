import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The paywall, drawn by RevenueCat.
///
/// The layout lives in the RevenueCat dashboard, so this screen holds no
/// pitch, no plan rows and no legal links. RevenueCat's paywall carries all of
/// them, including Restore Purchases, Terms of Use and Privacy Policy, which
/// is what the stores ask for.
///
/// The screen itself is an empty canvas. It opens RevenueCat's paywall on the
/// first frame and leaves as soon as that sheet closes, so the user never sees
/// two paywalls stacked on each other.
class HostedPaywallScreen extends StatelessWidget {
  const HostedPaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PaywallCubit>(),
      child: const _HostedPaywallLauncher(),
    );
  }
}

class _HostedPaywallLauncher extends StatefulWidget {
  const _HostedPaywallLauncher();

  @override
  State<_HostedPaywallLauncher> createState() => _HostedPaywallLauncherState();
}

class _HostedPaywallLauncherState extends State<_HostedPaywallLauncher> {
  @override
  void initState() {
    super.initState();
    unawaited(_present());
  }

  Future<void> _present() async {
    final cubit = context.read<PaywallCubit>();
    try {
      await cubit.loadSubscriptionData();
      await cubit.presentNativePaywall();
    } on Object catch (_) {
      // RevenueCat could not draw its paywall. Leaving is better than parking
      // the user on an empty canvas with no way out. The SDK has already shown
      // its own error alert by this point.
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      body: const SizedBox.expand(),
    );
  }
}
