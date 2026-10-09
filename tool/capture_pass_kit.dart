// What every Personalize capture tool shares: the device sizes, themes, text
// scales, plan states, reduce motion, the file names, and one function that
// draws a widget and writes the PNG. Not part of the app.
//
// The page tools (`capture_passes.dart` for the design system, and one per
// page after it) build on this:
//
//   registerPassShot(
//     page: 'stack',
//     device: passPhone,
//     mode: ThemeMode.light,
//     scale: 1,
//     build: (context) => ...,
//   );
//
// Every file is named
//   <page>_<state>_<phone>_<theme>_<scale>x_<frame>.png
// for example `sound_free_390x844_dark_1.3x_rest.png`. A shot that overflows
// fails. Optional, for every tool that uses the kit:
//   --dart-define=OUT=<folder>        where the PNGs go (default
//                                     build/captures)
//   --dart-define=ONLY=<part>,<part>  only files whose name has one of these
//                                     parts, such as 390x844_dark
//
// Developer tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';
import 'capture_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/captures');
const _only = String.fromEnvironment('ONLY');

/// A display a page is captured on.
class PassDevice {
  const PassDevice(
    this.name,
    this.size, {
    required this.safeTop,
    this.safeBottom = 0,
  });

  /// The width and height in the file name, such as `390x844`.
  final String name;
  final Size size;

  /// The inset at the top of the display, and at the bottom.
  final double safeTop;
  final double safeBottom;

  /// A display wider than a phone, where the column is centred.
  bool get isWide => size.width >= AppSize.mediumMinWidth || isShort;

  /// A phone on its side.
  bool get isShort => size.height < AppSize.shortMaxHeight;

  EdgeInsets get padding => EdgeInsets.only(top: safeTop, bottom: safeBottom);
}

const PassDevice passPhone = PassDevice(
  '390x844',
  Size(390, 844),
  safeTop: 47,
  safeBottom: 34,
);
const PassDevice passSmallPhone = PassDevice(
  '375x667',
  Size(375, 667),
  safeTop: 20,
);
const PassDevice passNarrowPhone = PassDevice(
  '320x640',
  Size(320, 640),
  safeTop: 20,
);
const PassDevice passMedium = PassDevice(
  '600x844',
  Size(600, 844),
  safeTop: 24,
  safeBottom: 20,
);
const PassDevice passTablet = PassDevice(
  '1024x768',
  Size(1024, 768),
  safeTop: 24,
  safeBottom: 20,
);
const PassDevice passSideways = PassDevice(
  '844x390',
  Size(844, 390),
  safeTop: 0,
);

/// The displays of the matrix: three phones, a tablet on its side and a phone
/// on its side. [passMedium] is the 600 wide one, for the stack.
const List<PassDevice> passDevices = [
  passPhone,
  passSmallPhone,
  passNarrowPhone,
  passTablet,
  passSideways,
];

/// The text scales of the matrix for [device]: 1.0, 1.3 and 2.0 at 390 and
/// 320 wide, 1.0 and 1.3 at 375, 1.0 on the wide displays.
List<double> passScalesFor(PassDevice device) {
  if (device.isWide) return const [1];
  if (device.size.width == 375) return const [1, 1.3];
  return const [1, 1.3, 2];
}

/// The themes of the matrix.
const List<ThemeMode> passThemes = [ThemeMode.light, ThemeMode.dark];

/// The state of the plan a page is captured in.
class PassPlanState {
  const PassPlanState(
    this.name, {
    this.preset,
    this.isPlanRead = true,
    this.isOwnServer = false,
  });

  /// The name in the file.
  final String name;

  /// The developer preset that holds the plan, or null where there is no
  /// preset (the plan still being read).
  final AccessPreset? preset;

  /// Whether the plan has been read. False draws no badge and waits at a tap.
  final bool isPlanRead;

  /// Whether the server is the user's own.
  final bool isOwnServer;

  static const PassPlanState free = PassPlanState(
    'free',
    preset: AccessPreset.free,
  );
  static const PassPlanState pro = PassPlanState(
    'pro',
    preset: AccessPreset.pro,
  );
  static const PassPlanState hosted = PassPlanState(
    'hosted',
    preset: AccessPreset.hosted,
  );
  static const PassPlanState notRead = PassPlanState(
    'notread',
    preset: AccessPreset.free,
    isPlanRead: false,
  );
  static const PassPlanState ownServer = PassPlanState(
    'own',
    preset: AccessPreset.pro,
    isOwnServer: true,
  );
  static const PassPlanState confirming = PassPlanState(
    'confirming',
    preset: AccessPreset.purchaseConfirming,
  );
  static const PassPlanState unreadable = PassPlanState(
    'unreadable',
    preset: AccessPreset.planUnreadable,
  );

  /// Every state, in the order of the matrix. The first five are captured at
  /// every size; confirming and unreadable at 390 by 844, light only.
  static const List<PassPlanState> all = [
    free,
    pro,
    hosted,
    notRead,
    ownServer,
    confirming,
    unreadable,
  ];
}

/// The file name of a shot, without the extension.
String passFileName({
  required String page,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  required String frame,
  String state = 'gallery',
}) => '${page}_${state}_${device.name}_${mode.name}_${scale}x_$frame';

/// Whether `ONLY` lets [name] through.
bool passWanted(String name) {
  final parts = _only.split(',').where((p) => p.isNotEmpty);
  return parts.isEmpty || parts.any(name.contains);
}

/// Call from `setUpAll` in a capture tool.
Future<void> setUpPassCaptures() async {
  SharedPreferences.setMockInitialValues({});
  await loadTestTranslations();
  await loadAppFonts();
}

/// What kind of picture a shot is.
enum PassShotKind {
  /// The widget fills the device, as the phone would show it.
  device,

  /// The widget at the device's width and as tall as it needs, with a margin.
  section,
}

/// Registers one shot: draws what [build] makes at [device]'s size, in [mode]
/// at text [scale], and writes `<OUT>/<name>.png`.
///
/// - [kind] decides whether the widget fills the device or sets its own
///   height.
/// - [reduceMotion] asks for the resting frame of every motion.
void registerPassShot({
  required String name,
  required PassDevice device,
  required ThemeMode mode,
  required double scale,
  required Widget Function(BuildContext context) build,
  PassShotKind kind = PassShotKind.device,
  bool reduceMotion = false,
}) {
  if (!passWanted(name)) return;
  testWidgets('capture $name', (tester) async {
    final errors = <String>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    // The test binding draws shadows hard. The app does not.
    debugDisableShadows = false;
    final isDevice = kind == PassShotKind.device;
    final width = isDevice ? device.size.width : device.size.width + 2 * 16;
    final height = isDevice ? device.size.height : 14000.0;
    tester.view.physicalSize = Size(width, height) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    try {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
              padding: isDevice ? device.padding : EdgeInsets.zero,
              viewPadding: isDevice ? device.padding : EdgeInsets.zero,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.appColors.canvas,
              body: isDevice
                  ? RepaintBoundary(key: key, child: build(context))
                  : Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: device.size.width,
                        child: SingleChildScrollView(
                          child: RepaintBoundary(
                            key: key,
                            child: ColoredBox(
                              color: context.appColors.canvas,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: build(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await _save(tester, key, name, isGood: errors.isEmpty);
      expect(errors, isEmpty, reason: errors.join('\n'));
    } finally {
      debugDisableShadows = true;
      FlutterError.onError = oldHandler;
    }
  });
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  required bool isGood,
}) => tester.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  print('${isGood ? 'FIT ' : 'BAD '} ${file.path}');
});
