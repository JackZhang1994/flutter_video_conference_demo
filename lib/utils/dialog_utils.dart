import 'package:flutter/material.dart';
import 'package:zego_permission/zego_permission.dart';

class DialogUtils {
  static void showSettingsLink(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('请到设置页面开启相机/麦克风权限，否则您将无法体验音视频功能'),
            actions: <Widget>[
              FlatButton(
                child: Text('去设置'),
                onPressed: () {
                  Navigator.of(context).pop();
                  ZegoPermission.openAppSettings();
                },
              ),
              FlatButton(
                child: Text('取消'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }
}
