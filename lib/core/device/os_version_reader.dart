/// Reads the major version of the phone's operating system: 18 for iOS 18.2,
/// 15 for Android 15.
// One method today, and it stays an interface so there is something to fake.
// ignore: one_member_abstracts
abstract interface class OsVersionReader {
  /// Null on the web, or when the phone could not say. Never throws.
  Future<int?> major();
}

/// Always answers the version it was given. For tests.
class FixedOsVersionReader implements OsVersionReader {
  const FixedOsVersionReader(this.value);

  final int? value;

  @override
  Future<int?> major() async => value;
}
