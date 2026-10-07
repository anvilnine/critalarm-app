import 'package:critalarm/core/device/device_maker.dart';

/// The phone makers that share one guide. A sub-brand goes with its parent:
/// Redmi and Poco with Xiaomi, Realme and OnePlus with Oppo, Honor with
/// Huawei.
enum MakerFamily { samsung, xiaomi, oppo, huawei }

/// Brand names Android reports, lower-cased, and the family each belongs to.
const Map<String, MakerFamily> _familyByName = {
  'samsung': MakerFamily.samsung,
  'xiaomi': MakerFamily.xiaomi,
  'redmi': MakerFamily.xiaomi,
  'poco': MakerFamily.xiaomi,
  'oppo': MakerFamily.oppo,
  'realme': MakerFamily.oppo,
  'oneplus': MakerFamily.oppo,
  'huawei': MakerFamily.huawei,
  'honor': MakerFamily.huawei,
};

/// The guide family for [maker], or null when no guide covers it.
///
/// The brand is read first, because it is the more specific name: a Redmi
/// reports Xiaomi as its manufacturer, and an older Honor reports Huawei.
/// The manufacturer is the fallback. Names are trimmed and lower-cased and
/// have to match whole.
///
/// Vivo is on `backgroundKillerMakers` and has no guide yet, so it answers
/// null here.
MakerFamily? makerFamilyFor(DeviceMaker maker) =>
    _familyByName[_normalised(maker.brand)] ??
    _familyByName[_normalised(maker.manufacturer)];

String _normalised(String name) => name.trim().toLowerCase();
