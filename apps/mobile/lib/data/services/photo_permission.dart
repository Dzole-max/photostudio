import 'package:photo_manager/photo_manager.dart';

enum PhotoAccess { granted, limited, denied, notDetermined }

/// Gallery permission, behind an interface so tests and desktop run without
/// a photo library.
abstract interface class PhotoPermissionService {
  Future<PhotoAccess> current();

  Future<PhotoAccess> request();

  /// iOS limited library: lets the user add more photos to the selection.
  Future<void> selectMore();

  Future<void> openSystemSettings();
}

class DevicePhotoPermissionService implements PhotoPermissionService {
  const DevicePhotoPermissionService();

  static const _options = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: true,
    ),
  );

  PhotoAccess _map(PermissionState s) => switch (s) {
    PermissionState.authorized => PhotoAccess.granted,
    PermissionState.limited => PhotoAccess.limited,
    PermissionState.notDetermined => PhotoAccess.notDetermined,
    PermissionState.denied || PermissionState.restricted => PhotoAccess.denied,
  };

  @override
  Future<PhotoAccess> current() async =>
      _map(await PhotoManager.getPermissionState(requestOption: _options));

  @override
  Future<PhotoAccess> request() async =>
      _map(await PhotoManager.requestPermissionExtend(requestOption: _options));

  @override
  Future<void> selectMore() =>
      PhotoManager.presentLimited(type: RequestType.image);

  @override
  Future<void> openSystemSettings() => PhotoManager.openSetting();
}

/// Always-granted permission for tests, simulators without photos and desktop.
class FakePhotoPermissionService implements PhotoPermissionService {
  FakePhotoPermissionService([this.state = PhotoAccess.granted]);

  PhotoAccess state;

  @override
  Future<PhotoAccess> current() async => state;

  @override
  Future<PhotoAccess> request() async => state;

  @override
  Future<void> selectMore() async {}

  @override
  Future<void> openSystemSettings() async {}
}
