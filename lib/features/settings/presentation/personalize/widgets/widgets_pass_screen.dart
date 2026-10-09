import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:flutter/material.dart';

/// The Widgets page: the header on the cream colour, and a body still to
/// come (the drawn widgets and the buttons).
class WidgetsPassScreen extends StatelessWidget {
  const WidgetsPassScreen({super.key});

  @override
  Widget build(BuildContext context) => PassLiveBuilder(
    builder: (context, live) => AppPassPage(
      tone: live.toneOf(PassId.widgets),
      label: live.labelOf(PassId.widgets),
      value: live.valueOf(PassId.widgets),
      tag: live.tagOf(PassId.widgets),
      isOn: live.isOn(PassId.widgets),
    ),
  );
}
