import 'package:critalarm/core/device/platform_os_version_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('majorOf reads the leading number', () {
    expect(PlatformOsVersionReader.majorOf('18.2.1'), 18);
    expect(PlatformOsVersionReader.majorOf('16'), 16);
    expect(PlatformOsVersionReader.majorOf(' 15.0'), 15);
    expect(PlatformOsVersionReader.majorOf('S'), isNull);
    expect(PlatformOsVersionReader.majorOf(''), isNull);
  });
}
