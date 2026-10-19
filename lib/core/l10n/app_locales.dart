import 'package:flutter/widgets.dart';

/// Pseudo-localization is opt-in and never listed in release or profile builds.
/// Tests pass these build values explicitly without needing a widget tree.
List<Locale> localesForBuild({
  required bool isDebug,
  required bool pseudoRequested,
}) => [
  const Locale('en'),
  if (isDebug && pseudoRequested) const Locale('en', 'XA'),
];

/// The locale a debug run starts in when `PSEUDO_LOCALE=true` is passed.
/// Null everywhere else, so easy_localization uses the saved or device locale.
Locale? pseudoStartLocale({
  required bool isDebug,
  required bool pseudoRequested,
}) => isDebug && pseudoRequested ? const Locale('en', 'XA') : null;
