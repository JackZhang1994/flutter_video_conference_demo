import 'package:zego_permission/zego_permission.dart';

class PermissionUtils {
  // 请求相机、麦克风权限
  static Future<Authorization> checkAuthorization() async {
    List<Permission> statusList =
        await ZegoPermission.getPermissions(<PermissionType>[PermissionType.Camera, PermissionType.MicroPhone]);

    if (statusList == null) return null;

    PermissionStatus cameraStatus, micStatus;
    for (var permission in statusList) {
      if (permission.permissionType == PermissionType.Camera) cameraStatus = permission.permissionStatus;
      if (permission.permissionType == PermissionType.MicroPhone) micStatus = permission.permissionStatus;
    }

    bool camReqResult = true, micReqResult = true;
    if (cameraStatus != PermissionStatus.granted || micStatus != PermissionStatus.granted) {
      //不管是第一次询问还是之前已拒绝，都直接请求权限
      if (cameraStatus != PermissionStatus.granted) {
        camReqResult = await ZegoPermission.requestPermission(PermissionType.Camera);
      }

      if (micStatus != PermissionStatus.granted) {
        micReqResult = await ZegoPermission.requestPermission(PermissionType.MicroPhone);
      }
    }

    return Authorization(camReqResult, micReqResult);
  }
}

class Authorization {
  final bool camera;
  final bool microphone;

  Authorization(this.camera, this.microphone);
}
