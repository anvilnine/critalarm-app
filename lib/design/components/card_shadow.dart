import 'package:critalarm/design/tokens/shadows.dart';
import 'package:flutter/widgets.dart';

/// Keeps the shadows of the cards under it small.
///
/// A detail pane leaves its cards only a narrow gutter to the pane's edge,
/// and the pane clips there. A large card shadow would make a grey band in
/// that gutter that stops dead at the edge. Under this scope a card casts
/// the small shadow of its own theme instead, which fades out inside the
/// gutter.
class AppCardShadowScope extends InheritedWidget {
  const AppCardShadowScope({required super.child, super.key});

  /// The shadow a card under [context] casts in place of [shadows]. Without
  /// a scope above, [shadows] as they are.
  static List<BoxShadow> of(BuildContext context, List<BoxShadow> shadows) {
    if (shadows.isEmpty) return shadows;
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppCardShadowScope>();
    if (scope == null) return shadows;
    return small(shadows);
  }

  /// The small shadow from the same theme as [shadows].
  static List<BoxShadow> small(List<BoxShadow> shadows) {
    if (shadows.isEmpty) return shadows;
    final isDark =
        identical(shadows, AppShadows.darkSm) ||
        identical(shadows, AppShadows.darkMd) ||
        identical(shadows, AppShadows.darkLg);
    return isDark ? AppShadows.darkSm : AppShadows.lightSm;
  }

  @override
  bool updateShouldNotify(AppCardShadowScope oldWidget) => false;
}
