import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What the user chose on the tour offer.
enum TourOfferAnswer { accept, decline }

/// Asks whether the user wants to be shown around, and resolves with their
/// answer, or null when the sheet is dismissed or closed from outside. The
/// TourHost treats null as "not now".
///
/// [onShown] gets the sheet's own context, so the caller can later close
/// exactly this sheet and nothing else.
Future<TourOfferAnswer?> showTourOfferSheet(
  BuildContext context, {
  void Function(BuildContext sheetContext)? onShown,
}) {
  return showAppSheet<TourOfferAnswer>(
    context: context,
    content: (sheetContext) {
      onShown?.call(sheetContext);
      return _TourOffer(
        onAccept: () => Navigator.of(sheetContext).pop(TourOfferAnswer.accept),
        onDecline: () =>
            Navigator.of(sheetContext).pop(TourOfferAnswer.decline),
      );
    },
  );
}

/// The body of the offer: a face, the question, what the tour is, where to
/// find it later, and the two ways out.
class _TourOffer extends StatelessWidget {
  const _TourOffer({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: FaceWidget(state: FaceState.watching, size: 88),
        ),
        const SizedBox(height: Spacing.s3),
        Text(
          LocaleKeys.tour_offer_title.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontDisplay,
            fontFamilyFallback: AppTypography.fontDisplayFallbacks,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.02 * 19,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.tour_offer_body.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink2),
        ),
        const SizedBox(height: 16),
        AppNote(text: LocaleKeys.tour_offer_note.tr()),
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.tour_offer_accept.tr(),
          isFullWidth: true,
          onPressed: onAccept,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.tour_offer_decline.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: onDecline,
        ),
      ],
    );
  }
}
