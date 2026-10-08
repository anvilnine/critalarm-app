// Shared by the capture tools under tool/. Not part of the app.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/services.dart';

/// Registers every font family the app ships, from the files `pubspec.yaml`
/// names for it, plus Material Icons from the Flutter SDK.
///
/// A widget test starts with only the Ahem test font, so a capture that skips
/// this draws every glyph as a box. Reading the families from `pubspec.yaml`
/// instead of listing them here keeps the captures on the real files when a
/// weight is added or a family is swapped: an earlier hand-written list
/// registered Bricolage Grotesque from an Archivo file, and every shot came
/// out in the wrong typeface.
Future<void> loadAppFonts({String pubspecPath = 'pubspec.yaml'}) async {
  final families = parsePubspecFonts(File(pubspecPath).readAsLinesSync());
  if (families.isEmpty) {
    throw StateError('No fonts found in $pubspecPath');
  }
  for (final MapEntry(key: family, value: assets) in families.entries) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(_read(asset));
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(_read(icons.path));
      await loader.load();
    } else {
      print('warning: ${icons.path} is missing, icons will draw as boxes');
    }
  }
}

/// Family name to the asset paths listed under it in the `flutter: fonts:`
/// section of `pubspec.yaml`, in file order.
Map<String, List<String>> parsePubspecFonts(List<String> lines) {
  final families = <String, List<String>>{};
  final family = RegExp(r'^\s*-\s*family:\s*(.+?)\s*$');
  final asset = RegExp(r'^\s*-\s*asset:\s*(.+?)\s*$');
  var inFonts = false;
  String? current;
  for (final line in lines) {
    if (RegExp(r'^  fonts:\s*$').hasMatch(line)) {
      inFonts = true;
      continue;
    }
    if (!inFonts) continue;
    // A line indented two spaces or less ends the fonts block.
    if (line.trim().isNotEmpty &&
        !line.trimLeft().startsWith('#') &&
        !line.startsWith('   ')) {
      break;
    }
    final f = family.firstMatch(line);
    if (f != null) {
      current = _unquote(f.group(1)!);
      families[current] = [];
      continue;
    }
    final a = asset.firstMatch(line);
    if (a != null && current != null) {
      families[current]!.add(_unquote(a.group(1)!));
    }
  }
  return families;
}

String _unquote(String s) => s.replaceAll(RegExp('^["\']|["\']\$'), '');

Future<ByteData> _read(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer);
}
