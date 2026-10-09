import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The part of a picture that shows in a frame, as fractions of the
/// picture.
///
/// The picture is laid out to cover the frame ([coverSize]) and then moved
/// and zoomed: a point of it lands at `scale * point + offset` in the
/// frame. Pure, so the crop a drag ends on is tested with no widget.
OwnPhotoCrop cropShownIn({
  required Size frame,
  required Size coverSize,
  required double scale,
  required Offset offset,
}) {
  if (scale <= 0 || coverSize.isEmpty || frame.isEmpty) {
    return OwnPhotoCrop.whole;
  }
  double part(double value, double whole) => (value / whole).clamp(0.0, 1.0);
  final left = -offset.dx / scale;
  final top = -offset.dy / scale;
  return OwnPhotoCrop(
    left: part(left, coverSize.width),
    top: part(top, coverSize.height),
    right: part(left + frame.width / scale, coverSize.width),
    bottom: part(top + frame.height / scale, coverSize.height),
  );
}

/// The size a picture of [picture] pixels is laid out at so it just covers
/// [frame] with nothing left bare.
Size coverSizeFor({required Size picture, required Size frame}) {
  if (picture.isEmpty || frame.isEmpty) return frame;
  final scale = math.max(
    frame.width / picture.width,
    frame.height / picture.height,
  );
  return Size(picture.width * scale, picture.height * scale);
}

/// The crop step of the own look: the picked photo in a frame the shape
/// of this phone's screen. Drag moves it, a pinch zooms it, and the two
/// buttons under the frame zoom it for anyone who cannot pinch.
///
/// The frame starts on the middle of the photo, covering it, so "Use
/// this photo" works with no gesture at all.
///
/// It decodes nothing: [picture] is the import's one decode of the
/// picked photo, and the kept part is cut from the same picture. The
/// caller owns it and frees it once this screen has closed. [onUse] does
/// the saving: it gets the framed part and answers null when the photo
/// was kept, or the message to show when it was not. The screen closes
/// on null and answers true.
class OwnPhotoCropScreen extends StatefulWidget {
  const OwnPhotoCropScreen({
    required this.picture,
    required this.onUse,
    super.key,
  });

  /// The picked photo, already decoded.
  final ui.Image picture;

  final Future<String?> Function(OwnPhotoCrop crop) onUse;

  /// The closest the frame zooms in. Past this the kept part of a large
  /// photo would be a small corner of it.
  static const double maxZoom = 3;

  static Route<bool> route({
    required ui.Image picture,
    required Future<String?> Function(OwnPhotoCrop crop) onUse,
  }) => PageRouteBuilder<bool>(
    fullscreenDialog: true,
    pageBuilder: (context, _, _) =>
        OwnPhotoCropScreen(picture: picture, onUse: onUse),
    transitionsBuilder: (context, animation, _, child) =>
        MediaQuery.of(context).disableAnimations
        ? child
        : FadeTransition(opacity: animation, child: child),
  );

  @override
  State<OwnPhotoCropScreen> createState() => _OwnPhotoCropScreenState();
}

class _OwnPhotoCropScreenState extends State<OwnPhotoCropScreen> {
  final TransformationController _view = TransformationController();
  bool _isSaving = false;
  String? _error;

  /// The frame the view was last centred for.
  Size? _centredFor;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  Size get _pictureSize => Size(
    widget.picture.width.toDouble(),
    widget.picture.height.toDouble(),
  );

  /// Puts the middle of the photo in the middle of [frame], zoomed out.
  void _centre(Size frame) {
    if (_centredFor == frame) return;
    _centredFor = frame;
    final cover = coverSizeFor(picture: _pictureSize, frame: frame);
    _view.value = Matrix4.translationValues(
      -(cover.width - frame.width) / 2,
      -(cover.height - frame.height) / 2,
      0,
    );
  }

  /// Zooms about the middle of the frame, and keeps the photo covering it.
  void _zoom(double factor) {
    final frame = _centredFor;
    if (frame == null) return;
    final cover = coverSizeFor(picture: _pictureSize, frame: frame);
    final was = _view.value.getMaxScaleOnAxis();
    final next = (was * factor).clamp(1.0, OwnPhotoCropScreen.maxZoom);
    final translation = _view.value.getTranslation();
    // The point of the photo under the middle of the frame stays there.
    final centreX = (frame.width / 2 - translation.x) / was;
    final centreY = (frame.height / 2 - translation.y) / was;
    final dx = (frame.width / 2 - centreX * next).clamp(
      frame.width - cover.width * next,
      0.0,
    );
    final dy = (frame.height / 2 - centreY * next).clamp(
      frame.height - cover.height * next,
      0.0,
    );
    _view.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1);
  }

  Future<void> _use() async {
    final frame = _centredFor;
    if (frame == null || _isSaving) return;
    final translation = _view.value.getTranslation();
    final crop = cropShownIn(
      frame: frame,
      coverSize: coverSizeFor(picture: _pictureSize, frame: frame),
      scale: _view.value.getMaxScaleOnAxis(),
      offset: Offset(translation.x, translation.y),
    );
    setState(() {
      _isSaving = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onUse(crop);
    } on Object catch (_) {
      error = LocaleKeys.alarm_styles_own_error_save_failed.tr();
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screen = RingingPreview.screenOf(context).size;
    final picture = widget.picture;
    final error = _error;
    return Material(
      color: colors.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s4,
            Spacing.s1,
            Spacing.s4,
            Spacing.s3,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        LocaleKeys.alarm_styles_own_crop_title.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(
                          colors.onCanvas,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  AppDismissCross(
                    onPressed: () => Navigator.of(context).pop(false),
                    label: LocaleKeys.common_close.tr(),
                    color: colors.onCanvas,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.s3),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: screen.width / screen.height,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final frame = box.biggest;
                        final radius = BorderRadius.circular(
                          frame.width * 0.14,
                        );
                        _centre(frame);
                        return DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border.all(
                              color: colors.inkFixed,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: radius,
                            child: ColoredBox(
                              color: colors.inkFixed,
                              child: _frame(picture, frame),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.s3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      error ?? LocaleKeys.alarm_styles_own_crop_hint.tr(),
                      style: AppTypography.small(
                        colors.onCanvas,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: Spacing.s2),
                  AppIconButton(
                    glyph: GlyphType.minus,
                    size: 44,
                    ariaLabel: LocaleKeys.alarm_styles_own_crop_zoom_out.tr(),
                    onPressed: () => _zoom(1 / 1.25),
                  ),
                  const SizedBox(width: Spacing.s2),
                  AppIconButton(
                    glyph: GlyphType.plus,
                    size: 44,
                    ariaLabel: LocaleKeys.alarm_styles_own_crop_zoom_in.tr(),
                    onPressed: () => _zoom(1.25),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.s3),
              AppButton(
                label: LocaleKeys.alarm_styles_own_crop_use.tr(),
                variant: AppButtonVariant.ink,
                isFullWidth: true,
                isLoading: _isSaving,
                onPressed: () => unawaited(_use()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame(ui.Image picture, Size frame) {
    final cover = coverSizeFor(picture: _pictureSize, frame: frame);
    return Semantics(
      image: true,
      label: LocaleKeys.alarm_styles_own_crop_label.tr(),
      child: InteractiveViewer(
        transformationController: _view,
        constrained: false,
        maxScale: OwnPhotoCropScreen.maxZoom,
        // The photo always covers the frame: nothing bare is ever kept.
        minScale: 1,
        child: SizedBox.fromSize(
          size: cover,
          child: RawImage(
            image: picture,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}
