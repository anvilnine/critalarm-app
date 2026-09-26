/// The icons the app can show on the home screen.
///
/// [standard] is the icon every install starts with and the one the stores
/// list. The other three are Pro: the same face with a crown, shades, or
/// both. Their artwork lives in `assets/icon/src`, and
/// `tool/export_app_icons.sh` renders it for both platforms.
enum AppIcon {
  standard('default'),
  crowned('pro_crowned'),
  shades('pro_shades'),
  shadesCrown('pro_shades_crown');

  const AppIcon(this.platformName);

  /// The name the platform channel uses. iOS maps it to an alternate icon
  /// set, Android to an `activity-alias`.
  final String platformName;

  /// True for the icons only Pro can pick.
  bool get isPro => this != standard;

  /// The icon [name] stands for, or null for a name this build does not know.
  static AppIcon? fromPlatformName(String? name) {
    for (final icon in values) {
      if (icon.platformName == name) return icon;
    }
    return null;
  }
}
