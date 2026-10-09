import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Pro sheet's own route. It is a bottom sheet over whatever opened it,
/// so Back and a tap outside both close it.
const proPackSheetRouteName = 'proPack';
const proPackSheetPath = '/pro';

/// Opens the Pro sheet, naming what opened it.
Future<void> openProPackSheet(
  BuildContext context,
  ProPackSheetSource source,
) => context.pushNamed<void>(
  proPackSheetRouteName,
  queryParameters: {'source': source.wire},
);

/// The location [openProPackSheet] opens, for a caller that holds a router
/// and no context.
String proPackSheetLocation(ProPackSheetSource source) => Uri(
  path: proPackSheetPath,
  queryParameters: {'source': source.wire},
).toString();

/// A router page that shows [ProPackSheet] as a modal bottom sheet.
class ProPackSheetPage extends Page<void> {
  const ProPackSheetPage({required this.source, super.key, super.name});

  final ProPackSheetSource source;

  @override
  Route<void> createRoute(BuildContext context) => ModalBottomSheetRoute<void>(
    settings: this,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    modalBarrierColor: Colors.black.withValues(alpha: 0.45),
    sheetAnimationStyle: context.reduceMotion
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ProPackSheet(source: source),
  );
}
