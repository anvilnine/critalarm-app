import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Pro sheet's own route. It is a bottom sheet over whatever opened it,
/// so Back and a tap outside both close it.
const proPackSheetRouteName = 'proPack';
const proPackSheetPath = '/pro';

/// The query parameter that says the phone is on a server of its own.
const _selfHostedParam = 'self_hosted';

/// Opens the Pro sheet, naming what opened it.
///
/// [isSelfHosted] is the opener's own knowledge of the phone. The sheet
/// then says the check covers the push relay and not that server.
Future<void> openProPackSheet(
  BuildContext context,
  ProPackSheetSource source, {
  bool isSelfHosted = false,
}) => context.pushNamed<void>(
  proPackSheetRouteName,
  queryParameters: {
    'source': source.wire,
    if (isSelfHosted) _selfHostedParam: '1',
  },
);

/// Whether the route to the sheet says the phone is self-hosted.
bool proPackSheetIsSelfHosted(Uri uri) =>
    uri.queryParameters[_selfHostedParam] == '1';

/// A router page that shows [ProPackSheet] as a modal bottom sheet.
class ProPackSheetPage extends Page<void> {
  const ProPackSheetPage({
    required this.source,
    this.isSelfHosted = false,
    super.key,
    super.name,
  });

  final ProPackSheetSource source;
  final bool isSelfHosted;

  @override
  Route<void> createRoute(BuildContext context) => ModalBottomSheetRoute<void>(
    settings: this,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    modalBarrierColor: Colors.black.withValues(alpha: 0.45),
    sheetAnimationStyle: context.reduceMotion
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ProPackSheet(source: source, isSelfHosted: isSelfHosted),
  );
}
