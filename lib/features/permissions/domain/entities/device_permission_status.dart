/// The grant status of a device permission.
enum DevicePermissionStatus {
  /// Permission has been granted.
  granted,

  /// Permission was denied by user or policy.
  denied,

  /// Permission is restricted by parental controls or device policy.
  restricted,

  /// Status has not yet been determined or requested.
  notDetermined;

  bool get isGranted => this == DevicePermissionStatus.granted;
  bool get isDenied => this == DevicePermissionStatus.denied;
  bool get isRestricted => this == DevicePermissionStatus.restricted;
  bool get isNotDetermined => this == DevicePermissionStatus.notDetermined;
}
