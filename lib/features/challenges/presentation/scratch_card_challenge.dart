import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/scratch_card.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A card with a cover the finger rubs off, a four digit code under it,
/// and a number pad to type the code.
///
/// The code comes from a seed chosen once when the challenge opens. The
/// card counts as revealed when enough of the code's area is cleared
/// (`scratch_card.dart` has the rule). A button that shows the code is
/// offered after five seconds of rubbing, and with a screen reader the
/// code is read out and nothing is rubbed. It reads nothing from the
/// alarm.
final class ScratchCardChallenge implements Challenge {
  const ScratchCardChallenge();

  @override
  ChallengeKind get kind => ChallengeKind.scratchCard;

  @override
  String get nameKey => LocaleKeys.challenges_scratch_card_name;

  @override
  String get promptKey => LocaleKeys.challenges_scratch_card_prompt;

  /// A card needs nothing from the alarm.
  @override
  bool canRunFor(ChallengeIncident incident) => true;

  @override
  Widget build(BuildContext context, ChallengeRun run) =>
      _ScratchCard(run: run);
}

class _ScratchCard extends StatefulWidget {
  const _ScratchCard({required this.run});

  final ChallengeRun run;

  @override
  State<_ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<_ScratchCard> {
  /// The height of the card. Fixed, so the grid's cells keep their shape.
  static const double _cardHeight = 128;

  /// The room between two digits of the code.
  static const double _digitGap = 10;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _grid = ScratchGrid();
  final _rub = ScratchRub();
  final _clock = Stopwatch();

  /// The one path of everything rubbed so far, and what tells the painter
  /// it grew.
  final _strokes = Path();
  final _strokeCount = ValueNotifier<int>(0);

  late final String _code;
  Timer? _buttonTimer;
  int? _pointer;
  Offset? _last;
  bool _isRevealed = false;
  bool _isCoverGone = false;
  bool _isButtonOffered = false;
  bool _didPass = false;
  bool _wasWrong = false;

  @override
  void initState() {
    super.initState();
    _code = widget.run.isPicture
        ? scratchCodeSample
        : scratchCode(DateTime.now().microsecondsSinceEpoch);
    _focus.addListener(_redraw);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A screen reader cannot rub a card, so the code is there to be read
    // from the start.
    if (!widget.run.isPicture &&
        !_isRevealed &&
        MediaQuery.accessibleNavigationOf(context)) {
      _isRevealed = true;
      _isCoverGone = true;
    }
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _reveal() {
    if (_isRevealed) return;
    _buttonTimer?.cancel();
    _pointer = null;
    // With reduce motion nothing fades, so the cover is gone at once.
    final isStill = context.reduceMotion;
    setState(() {
      _isRevealed = true;
      if (isStill) _isCoverGone = true;
    });
    // After the frame, so the field exists to take it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _down(PointerDownEvent event, Size card) {
    if (_pointer != null || _isRevealed) return;
    _pointer = event.pointer;
    _clock.start();
    _rub.down(_clock.elapsed);
    if (!_isButtonOffered) {
      _buttonTimer?.cancel();
      _buttonTimer = Timer(_rub.untilButton(_clock.elapsed), () {
        if (mounted) setState(() => _isButtonOffered = true);
      });
    }
    _stroke(event.localPosition, event.localPosition, card);
  }

  void _move(PointerMoveEvent event, Size card) {
    if (event.pointer != _pointer) return;
    _stroke(_last ?? event.localPosition, event.localPosition, card);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _last = null;
    _rub.up(_clock.elapsed);
    _buttonTimer?.cancel();
  }

  void _stroke(Offset from, Offset to, Size card) {
    if (card.isEmpty) return;
    if (from == to) {
      _strokes
        ..moveTo(to.dx, to.dy)
        ..lineTo(to.dx, to.dy);
    } else {
      if (_last == null) _strokes.moveTo(from.dx, from.dy);
      _strokes.lineTo(to.dx, to.dy);
    }
    _last = to;
    _strokeCount.value++;
    _grid.rub(
      fromX: from.dx / card.width,
      fromY: from.dy / card.height,
      toX: to.dx / card.width,
      toY: to.dy / card.height,
      radiusX: ScratchRule.brushRadius / card.width,
      radiusY: ScratchRule.brushRadius / card.height,
    );
    if (_grid.isRevealed) _reveal();
  }

  /// [isFinal] is true when the person pressed done.
  void _check(String typed, {bool isFinal = false}) {
    if (_didPass) return;
    // A number pad has no done key on iOS, so four digits are judged as
    // soon as they are typed.
    switch (scratchCodeJudge(typed: typed, code: _code, isFinal: isFinal)) {
      case ScratchCodeVerdict.right:
        _didPass = true;
        widget.run.onPassed();
      case ScratchCodeVerdict.wrong:
        _controller.clear();
        setState(() => _wasWrong = true);
      case ScratchCodeVerdict.waiting:
        if (_wasWrong && typed.isNotEmpty) setState(() => _wasWrong = false);
    }
  }

  @override
  void dispose() {
    _buttonTimer?.cancel();
    _clock.stop();
    _strokeCount.dispose();
    _focus
      ..removeListener(_redraw)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _card(BuildContext context) {
    final colors = context.appColors;
    final isPicture = widget.run.isPicture;
    final code = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.s4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          // The spacing also follows the last digit, so the same room goes
          // in front of the first and the code sits in the middle.
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: _digitGap),
            child: Text(
              _code,
              maxLines: 1,
              style: AppTypography.monoBold(
                colors.ink,
                fontSize: 40,
              ).copyWith(letterSpacing: _digitGap),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: _cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final card = Size(constraints.maxWidth, _cardHeight);
          Widget cover = RepaintBoundary(
            child: CustomPaint(
              size: card,
              painter: _CoverPainter(
                strokes: _strokes,
                repaint: _strokeCount,
                cover: colors.yellow,
                line: colors.inkFixed.withValues(alpha: 0.1),
              ),
            ),
          );
          if (!isPicture && !_isRevealed) {
            cover = RawGestureDetector(
              // Takes the touch at once, so a rub up and down the card
              // never scrolls the page under it.
              gestures: {
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer
                    >(EagerGestureRecognizer.new, (_) {}),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _down(event, card),
                onPointerMove: (event) => _move(event, card),
                onPointerUp: _up,
                onPointerCancel: _up,
                child: cover,
              ),
            );
          }
          return ClipRRect(
            borderRadius: Radii.mdAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colors.surface),
                if (_isRevealed)
                  Semantics(
                    label: LocaleKeys.challenges_scratch_card_code_spoken.tr(
                      namedArgs: {'digits': scratchCodeSpelled(_code)},
                    ),
                    excludeSemantics: true,
                    child: code,
                  )
                else
                  ExcludeSemantics(child: code),
                if (!_isCoverGone)
                  Semantics(
                    button: true,
                    label: LocaleKeys.challenges_scratch_card_card_label.tr(),
                    // A switch or a keyboard cannot rub, so its action
                    // is the plain one.
                    onTap: isPicture || _isRevealed ? null : _reveal,
                    child: AnimatedOpacity(
                      opacity: _isRevealed ? 0 : 1,
                      duration: context.motion(AppDurations.base),
                      curve: AppCurves.easeOut,
                      onEnd: () {
                        if (mounted && _isRevealed) {
                          setState(() => _isCoverGone = true);
                        }
                      },
                      child: cover,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hint = AppTypography.small(colors.onCanvas, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The prompt over the card says to scratch and then type, so no
        // line under the card says either again.
        _card(context),
        if (!_isRevealed) ...[
          if (_isButtonOffered) ...[
            const SizedBox(height: Spacing.s3),
            AppButton(
              label: LocaleKeys.challenges_scratch_card_reveal.tr(),
              variant: AppButtonVariant.ghost,
              isFullWidth: true,
              onPressed: _reveal,
            ),
          ],
        ] else ...[
          const SizedBox(height: Spacing.s3),
          Semantics(
            label: LocaleKeys.challenges_scratch_card_field_label.tr(
              namedArgs: {'digits': scratchCodeSpelled(_code)},
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: Radii.mdAll,
                border: Border.all(
                  color: _focus.hasFocus ? colors.ink : colors.hairline,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.s4,
                  vertical: Spacing.s3,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(scratchCodeLength),
                  ],
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  // Room for the way out, pinned under the field.
                  scrollPadding: challengeFieldScrollPadding,
                  style: AppTypography.monoBold(colors.ink, fontSize: 24),
                  cursorColor: colors.cobalt,
                  onChanged: _check,
                  onSubmitted: (typed) => _check(typed, isFinal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          if (_wasWrong) ...[
            const SizedBox(height: Spacing.s2),
            Semantics(
              liveRegion: true,
              child: Text(
                LocaleKeys.challenges_scratch_card_wrong.tr(),
                textAlign: TextAlign.center,
                style: hint,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The cover of the card with everything rubbed so far cut out of it.
///
/// It keeps its paints and the one stripe path between frames. A frame
/// draws the cover and one stroked path, and allocates nothing.
class _CoverPainter extends CustomPainter {
  _CoverPainter({
    required this.strokes,
    required Listenable repaint,
    required this.cover,
    required this.line,
  }) : super(repaint: repaint);

  final Path strokes;
  final Color cover;
  final Color line;

  static const double _stripeGap = 14;

  final Paint _layer = Paint();
  late final Paint _fill = Paint()..color = cover;
  late final Paint _stripe = Paint()
    ..color = line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _cut = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = ScratchRule.brushRadius * 2;

  Path? _stripes;
  Size? _stripesFor;

  Path _stripesOf(Size size) {
    final cached = _stripes;
    if (cached != null && _stripesFor == size) return cached;
    final path = Path();
    for (var x = -size.height; x < size.width; x += _stripeGap) {
      path
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0);
    }
    _stripesFor = size;
    return _stripes = path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas
      ..saveLayer(bounds, _layer)
      ..drawRect(bounds, _fill)
      ..drawPath(_stripesOf(size), _stripe)
      ..drawPath(strokes, _cut)
      ..restore();
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.cover != cover || old.line != line || old.strokes != strokes;
}
