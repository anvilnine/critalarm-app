import 'package:flutter/foundation.dart';

/// Who made this phone, as Android reports it.
///
/// Android gives two names. `manufacturer` is the company that built the
/// phone and `brand` is the name on the box, and they differ on sub-brands:
/// a Redmi reports Xiaomi as its manufacturer and Redmi as its brand. Both
/// are kept as reported, so the caller decides how to compare them.
@immutable
class DeviceMaker {
  const DeviceMaker({this.manufacturer = '', this.brand = ''});

  /// Not an Android phone, or the read failed.
  static const unknown = DeviceMaker();

  final String manufacturer;
  final String brand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceMaker &&
          manufacturer == other.manufacturer &&
          brand == other.brand;

  @override
  int get hashCode => Object.hash(manufacturer, brand);

  @override
  String toString() => 'DeviceMaker($manufacturer, $brand)';
}

/// Reads the phone's maker. Behind an interface so a test, or a debug run on
/// an emulator, can hand in a maker the device does not have.
// One method today, and it stays an interface so there is something to fake.
// ignore: one_member_abstracts
abstract interface class DeviceMakerReader {
  /// Never throws. A phone that cannot say answers [DeviceMaker.unknown].
  Future<DeviceMaker> read();
}

/// Always answers the maker it was given.
class FixedDeviceMakerReader implements DeviceMakerReader {
  const FixedDeviceMakerReader(this.maker);

  /// A phone that reports [name] as both its manufacturer and its brand.
  FixedDeviceMakerReader.named(String name)
    : maker = DeviceMaker(manufacturer: name, brand: name);

  final DeviceMaker maker;

  @override
  Future<DeviceMaker> read() async => maker;
}

/// Reads the Android API level of this phone. Null off Android, or when the
/// phone could not say.
// One method today, and it stays an interface so there is something to fake.
// ignore: one_member_abstracts
abstract interface class AndroidSdkReader {
  Future<int?> sdkInt();
}
