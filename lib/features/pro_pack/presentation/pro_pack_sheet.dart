import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_cubit.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_state.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Pro sheet: what Pro is, that it is a purchase of its own beside
/// Hosted, what the store has on sale, and Restore.
///
/// Every title and price on it is the store's own string. With nothing on
/// sale it says so and offers nothing to buy. Restore stays, so a buyer on
/// a second phone can still bring the pack over. What to draw comes from
/// `ProPackSheetCubit`; the face and words for each stage come from
/// `proPackSheetView`.
class ProPackSheet extends StatelessWidget {
  const ProPackSheet({this.source = ProPackSheetSource.direct, super.key});

  final ProPackSheetSource source;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProPackSheetCubit>(
      create: (_) {
        final cubit = getIt<ProPackSheetCubit>();
        unawaited(cubit.open(source));
        return cubit;
      },
      child: const _ProPackSheetBody(),
    );
  }
}

class _ProPackSheetBody extends StatefulWidget {
  const _ProPackSheetBody();

  @override
  State<_ProPackSheetBody> createState() => _ProPackSheetBodyState();
}

class _ProPackSheetBodyState extends State<_ProPackSheetBody> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<ProPackSheetCubit>();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: BlocBuilder<ProPackSheetCubit, ProPackSheetState>(
        builder: (context, state) {
          final view = proPackSheetView(state.stage);
          final note = state.note;
          final showsOffers = state.stage == ProPackSheetStage.offers;

          return AppBottomSheet(
            scrollController: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (view.isWaiting)
                  Center(
                    child: AppWaitingFace(
                      message: view.titleKey.tr(),
                      faceSize: 72,
                    ),
                  )
                else ...[
                  Center(
                    child: ExcludeSemantics(
                      child: FaceWidget(state: view.face, size: 72),
                    ),
                  ),
                  const SizedBox(height: Spacing.s3),
                  Semantics(
                    header: true,
                    child: Text(
                      view.titleKey.tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.headline(colors.ink, fontSize: 22),
                    ),
                  ),
                  if (view.lineKey != null) ...[
                    const SizedBox(height: Spacing.s1),
                    Text(
                      view.lineKey!.tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.body(colors.ink2, fontSize: 15),
                    ),
                  ],
                ],
                if (showsOffers ||
                    state.stage == ProPackSheetStage.notOnSale) ...[
                  const SizedBox(height: Spacing.s2),
                  Text(
                    LocaleKeys.pro_pack_sheet_why.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.small(colors.ink3, fontSize: 13),
                  ),
                ],
                if (state.stage == ProPackSheetStage.notOnSale) ...[
                  const SizedBox(height: Spacing.s4),
                  Text(
                    LocaleKeys.pro_pack_sheet_not_on_sale.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      colors.ink,
                      fontSize: 15,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: Spacing.s3),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      proPackSheetNoteKey(note).tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.small(colors.ink, fontSize: 13),
                    ),
                  ),
                ],
                if (showsOffers) ...[
                  const SizedBox(height: Spacing.s3),
                  for (final offer in state.offers) ...[
                    _OfferRow(
                      offer: offer,
                      onTap: () => unawaited(cubit.buy(offer)),
                    ),
                    const SizedBox(height: Spacing.s2),
                  ],
                ],
                if (state.stage == ProPackSheetStage.checkingPaused) ...[
                  const SizedBox(height: Spacing.s4),
                  AppButton(
                    label: LocaleKeys.pro_pack_sheet_check_again.tr(),
                    isFullWidth: true,
                    onPressed: () => unawaited(cubit.checkAgain()),
                  ),
                ],
                // Restore sits under whatever the sheet rests on, with or
                // without anything on sale. A row hands its child no width,
                // so the button stays as wide as its label.
                if (ProPackSheetCubit.canRestore(state.stage)) ...[
                  if (!showsOffers) const SizedBox(height: Spacing.s3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppButton(
                        label: LocaleKeys.pro_pack_sheet_restore.tr(),
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        onPressed: () => unawaited(cubit.restore()),
                      ),
                    ],
                  ),
                ],
                if (state.stage == ProPackSheetStage.held) ...[
                  const SizedBox(height: Spacing.s4),
                  AppButton(
                    label: LocaleKeys.pro_pack_sheet_done.tr(),
                    isFullWidth: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One package from the store: its title and its price, as the store wrote
/// them. A tap starts the purchase, and the store asks to confirm it.
class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.onTap});

  final ProPackOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final strong = AppTypography.body(
      colors.onCanvas,
      fontSize: 15,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.3);

    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          // An open choice, so the tone that claims no state.
          child: AppHighlightCard(
            tone: AppHighlightTone.choice,
            // The price drops under the title when the two do not fit on
            // one line, so neither is cut.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Spacing.s3,
              runSpacing: Spacing.s1,
              children: [
                Text(offer.title, style: strong), // l10n-ok: the store's text
                Text(offer.price, style: strong), // l10n-ok: the store's text
              ],
            ),
          ),
        ),
      ),
    );
  }
}
