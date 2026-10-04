import 'package:critalarm/core/device/device_maker.dart';

/// Phone makers whose Android kills background apps beyond stock Doze.
///
/// On these phones the battery exemption is what keeps a page on time, so
/// setup offers it. Stock Android, a Pixel included, does not need it: a
/// high-priority push wakes the app out of Doze there.
///
/// Lower-cased. This is the only copy of the list: add a maker here and
/// nowhere else.
const Set<String> backgroundKillerMakers = {
  'samsung',
  'xiaomi',
  'redmi',
  'poco',
  'oppo',
  'realme',
  'oneplus',
  'vivo',
  'huawei',
  'honor',
};

/// Whether [maker] is on [backgroundKillerMakers].
///
/// Both names Android reports are compared, trimmed and lower-cased, and
/// either one matching is enough: a sub-brand reports its parent as the
/// manufacturer and itself as the brand. A name has to match whole, so a
/// maker that only contains a listed name is not on the list.
bool makerKillsBackgroundApps(DeviceMaker maker) =>
    backgroundKillerMakers.contains(_normalised(maker.manufacturer)) ||
    backgroundKillerMakers.contains(_normalised(maker.brand));

String _normalised(String name) => name.trim().toLowerCase();
