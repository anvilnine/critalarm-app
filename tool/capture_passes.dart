// Captures the Personalize design system parts as the gallery draws them, off
// the device, with made-up data.
//
//   fvm flutter test tool/capture_passes.dart
//
// It writes one PNG per part, display, theme and text size:
//   cards     every pass card, tagged and not, a two-line value, a long
//             own-sound name, overlapped and flat (a section, full height)
//   stack     the header and the stack, as a phone shows it
//   stackfull the same, as tall as its scroll content, where it scrolls
//   page-*    the page scaffold: sound, challenge, widgets, appIcon, look,
//             longValue
//   frames-*  the grow at progress 0, 0.25, 0.5, 0.75 and 1, opening and
//             closing, for the sound, widgets and challenge cards
//   reduce-*  the resting frames under reduce motion, and the fade
//
// Displays: 390 by 844, 375 by 667, 320 by 640, 1024 by 768, 844 by 390,
// and 600 by 844 for the stack. Light and dark. Text scale 1.0, 1.3 and 2.0
// at 390 and 320, 1.0 and 1.3 at 375, 1.0 on the wide ones. The frames and
// the reduce motion shots are at 390 by 844. The kit has the details
// (`capture_pass_kit.dart`), including the `OUT` and `ONLY` options.
//
//   --dart-define=PARTS=cards,stack   only these of cards, stack, stackfull,
//                                     page, frames, reduce
//
// Plan states do not apply: this is the gallery, not a page.
//
// This captures stills. It does not show the grow playing.
//
// Developer tool.

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/gallery/passes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_pass_kit.dart';

const _partsArg = String.fromEnvironment('PARTS');

void main() {
  final parts = _partsArg.isEmpty
      ? {'cards', 'stack', 'stackfull', 'page', 'frames', 'reduce'}
      : _partsArg.split(',').toSet();

  setUpAll(setUpPassCaptures);

  for (final mode in passThemes) {
    for (final device in [...passDevices, passMedium]) {
      // The 600 wide display is for the stack only.
      final isMediumOnly = device == passMedium;
      for (final scale in passScalesFor(device)) {
        String name(String page) => passFileName(
          page: page,
          device: device,
          mode: mode,
          scale: scale,
          frame: 'rest',
        );

        if (parts.contains('cards') && !isMediumOnly) {
          registerPassShot(
            name: name('cards'),
            device: device,
            mode: mode,
            scale: scale,
            kind: PassShotKind.section,
            build: (_) => const PassCardsGallery(),
          );
        }
        if (parts.contains('stack')) {
          registerPassShot(
            name: name('stack'),
            device: device,
            mode: mode,
            scale: scale,
            build: (_) => PassStackDemo(
              size: device.size,
              safeTop: device.safeTop,
              safeBottom: device.safeBottom,
              textScale: scale,
            ),
          );
        }
        if (parts.contains('stackfull') && scale >= 1.3 && !device.isWide) {
          // Flat cards scroll. A tall display shows all of them.
          final tall = Size(device.size.width, scale >= 2 ? 1600 : 1300);
          registerPassShot(
            name: name('stackfull'),
            device: PassDevice(
              device.name,
              tall,
              safeTop: device.safeTop,
              safeBottom: device.safeBottom,
            ),
            mode: mode,
            scale: scale,
            build: (_) => PassStackDemo(
              size: tall,
              safeTop: device.safeTop,
              safeBottom: device.safeBottom,
              textScale: scale,
            ),
          );
        }
        if (parts.contains('page') && !isMediumOnly) {
          for (final variant in PassPageVariant.values) {
            registerPassShot(
              name: name('page-${variant.name}'),
              device: device,
              mode: mode,
              scale: scale,
              build: (_) => PassPageDemo(
                variant: variant,
                size: device.size,
                safeTop: device.safeTop,
                safeBottom: device.safeBottom,
                textScale: scale,
              ),
            );
          }
        }
      }
    }

    // The grow, at 390 by 844 and the default text size.
    for (final pass in [PassId.sound, PassId.widgets, PassId.challenge]) {
      for (final reverse in [false, true]) {
        for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final frameName = '${reverse ? 'back' : 'open'}$progress';
          if (parts.contains('frames')) {
            registerPassShot(
              name: passFileName(
                page: 'frames-${pass.name}',
                device: passPhone,
                mode: mode,
                scale: 1,
                frame: frameName,
              ),
              device: passPhone,
              mode: mode,
              scale: 1,
              build: (_) => PassFramePreview(
                progress: progress,
                reverse: reverse,
                pass: pass,
                scale: 1,
              ),
            );
          }
        }
      }
    }

    // Reduce motion: the resting stack and page, and the fade at 0.5.
    if (parts.contains('reduce')) {
      registerPassShot(
        name: passFileName(
          page: 'reduce-stack',
          device: passPhone,
          mode: mode,
          scale: 1,
          frame: 'rest',
        ),
        device: passPhone,
        mode: mode,
        scale: 1,
        reduceMotion: true,
        build: (_) => PassStackDemo(
          size: passPhone.size,
          safeBottom: passPhone.safeBottom,
        ),
      );
      registerPassShot(
        name: passFileName(
          page: 'reduce-page',
          device: passPhone,
          mode: mode,
          scale: 1,
          frame: 'rest',
        ),
        device: passPhone,
        mode: mode,
        scale: 1,
        reduceMotion: true,
        build: (_) => PassPageDemo(
          variant: PassPageVariant.sound,
          size: passPhone.size,
          safeBottom: passPhone.safeBottom,
        ),
      );
      for (final progress in [0.0, 0.5, 1.0]) {
        registerPassShot(
          name: passFileName(
            page: 'reduce-frames-sound',
            device: passPhone,
            mode: mode,
            scale: 1,
            frame: 'open$progress',
          ),
          device: passPhone,
          mode: mode,
          scale: 1,
          reduceMotion: true,
          build: (_) => PassFramePreview(
            progress: progress,
            reduceMotion: true,
            scale: 1,
          ),
        );
      }
    }
  }
}
