import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:flutter/material.dart';

/// The Wake-up challenge page: the header on the panel colour, and a body
/// still to come (the shelf of challenges).
class ChallengePassScreen extends StatelessWidget {
  const ChallengePassScreen({super.key});

  @override
  Widget build(BuildContext context) => PassLiveBuilder(
    builder: (context, live) => AppPassPage(
      tone: live.toneOf(PassId.challenge),
      label: live.labelOf(PassId.challenge),
      value: live.valueOf(PassId.challenge),
      tag: live.tagOf(PassId.challenge),
      isOn: live.isOn(PassId.challenge),
    ),
  );
}
