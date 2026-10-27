import 'package:critalarm/core/format/date_label.dart';
import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sink.dart';
import 'package:critalarm/features/in_app_notices/presentation/cancel_question/cancel_question_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cancel_question/cancel_reason_chip.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the cancel question over the screen behind it. [endsAt] is the day
/// the plan runs out, shown as the sheet's last line. Answers go to [sink]
/// and nowhere else. Completes when the sheet closes, however it closes.
///
/// Deciding when to ask is not this sheet's job.
Future<void> showCancelQuestionSheet(
  BuildContext context, {
  required DateTime endsAt,
  required CancelAnswerSink sink,
}) {
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => BlocProvider(
      create: (_) => CancelQuestionCubit(sink),
      child: CancelQuestionSheet(
        endsAt: endsAt,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}

/// The body of the cancel question: a face and the question, six reasons, an
/// optional text field once one is picked, and a last line that says when the
/// plan ends. It has no price, no offer and no way into a paywall.
///
/// The body scrolls once the text is large or the keyboard is up, so the
/// cross and Send stay in reach.
class CancelQuestionSheet extends StatefulWidget {
  const CancelQuestionSheet({
    required this.endsAt,
    required this.onClose,
    super.key,
  });

  final DateTime endsAt;
  final VoidCallback onClose;

  @override
  State<CancelQuestionSheet> createState() => _CancelQuestionSheetState();
}

class _CancelQuestionSheetState extends State<CancelQuestionSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  void _onText() {
    final hasText = trimCancelText(_controller.text).isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  String _label(CancelReason reason) => switch (reason) {
    CancelReason.price => LocaleKeys.cancel_question_reason_price.tr(),
    CancelReason.unused => LocaleKeys.cancel_question_reason_unused.tr(),
    CancelReason.selfhost => LocaleKeys.cancel_question_reason_selfhost.tr(),
    CancelReason.missing => LocaleKeys.cancel_question_reason_missing.tr(),
    CancelReason.broken => LocaleKeys.cancel_question_reason_broken.tr(),
    CancelReason.other => LocaleKeys.cancel_question_reason_other.tr(),
  };

  /// Lets the sheet change height without a jump: the field opening, the
  /// sheet settling on thanks. Under reduced motion the new height is simply
  /// there, because an animated size with no duration cannot lay out a child
  /// that changes.
  Widget _grow(BuildContext context, {required Widget child}) {
    if (context.reduceMotion) return child;
    return AnimatedSize(
      duration: AppDurations.quick,
      curve: AppCurves.easeOut,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom) * 0.8;

    // A chip is its text (14 at 1.4), 8 above and below, and the 1.5 stroke.
    // It sits in a 48 tap box, taller than it by [room] at the default text
    // size. The gap between two rows gives up that room so the rows keep
    // their distance. A chip that wraps is taller than the box and needs none.
    final chipHeight = media.textScaler.scale(14) * 1.4 + 2 * Spacing.s2 + 3;
    final room = chipHeight >= kMinTapTarget ? 0.0 : kMinTapTarget - chipHeight;

    return BlocBuilder<CancelQuestionCubit, CancelQuestionState>(
      builder: (context, state) {
        final cubit = context.read<CancelQuestionCubit>();
        final step = state.step;
        final isThanks = step == CancelQuestionStep.thanks;
        final isExplain = step == CancelQuestionStep.explain;

        final header = Row(
          children: [
            FaceWidget(
              state: isThanks ? FaceState.happy : FaceState.calm,
              size: 40,
            ),
            const SizedBox(width: Spacing.s3),
            Expanded(
              child: Text(
                isThanks
                    ? LocaleKeys.cancel_question_thanks_title.tr()
                    : LocaleKeys.cancel_question_title.tr(),
                style: AppTypography.title(colors.ink),
              ),
            ),
            AppDismissCross(
              onPressed: widget.onClose,
              label: LocaleKeys.common_close.tr(),
              tapSize: 48,
            ),
          ],
        );

        final keeps = Text(
          LocaleKeys.cancel_question_keeps.tr(
            // A no-break space keeps "9" and "Nov" on one line.
            namedArgs: {
              'date': DateLabel.dayMonth(
                widget.endsAt,
              ).replaceAll(' ', '\u00A0'),
            },
          ),
          style: AppTypography.small(colors.ink3, fontSize: 12),
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: _grow(
              context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isThanks)
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          header,
                          const SizedBox(height: Spacing.s3),
                          keeps,
                        ],
                      ),
                    )
                  else ...[
                    header,
                    const SizedBox(height: Spacing.s2),
                    Wrap(
                      spacing: Spacing.s2,
                      runSpacing: room < Spacing.s2 ? Spacing.s2 - room : 0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final reason in CancelReason.values)
                          CancelReasonChip(
                            label: _label(reason),
                            isSelected: state.reason == reason,
                            onTap: step == CancelQuestionStep.question
                                ? () => cubit.pick(reason)
                                : null,
                          ),
                      ],
                    ),
                    if (isExplain)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.s3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _controller,
                              isMono: false,
                              growToFit: true,
                              maxLength: kCancelTextMaxChars,
                              placeholder: LocaleKeys
                                  .cancel_question_explain_hint
                                  .tr(),
                              textCapitalization: TextCapitalization.sentences,
                              scrollPadding: const EdgeInsets.only(
                                bottom: 120,
                              ),
                            ),
                            const SizedBox(height: Spacing.s2),
                            AppButton(
                              label: LocaleKeys.cancel_question_send.tr(),
                              variant: AppButtonVariant.ink,
                              isFullWidth: true,
                              onPressed: _hasText
                                  ? () => cubit.send(_controller.text)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Spacing.s3),
                    keeps,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
