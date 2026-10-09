import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:flutter/material.dart';

/// The Look page: the header on the colour of the look that rings, and a
/// body still to come (the deck of looks). It reads its tone from
/// `lookPassToneFor` through [PassLive], so the card it grew from and this
/// page are one colour.
class LookPassScreen extends StatelessWidget {
  const LookPassScreen({super.key});

  @override
  Widget build(BuildContext context) => PassLiveBuilder(
    builder: (context, live) => AppPassPage(
      tone: live.toneOf(PassId.look),
      label: live.labelOf(PassId.look),
      value: live.valueOf(PassId.look),
      tag: live.tagOf(PassId.look),
      isOn: live.isOn(PassId.look),
    ),
  );
}
