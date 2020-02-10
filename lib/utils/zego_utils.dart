import 'package:flutter/material.dart';
import 'package:flutter_jigou/utils/dialog_utils.dart';
import 'package:flutter_jigou/utils/permission_utils.dart';
import 'package:flutter_jigou/utils/uuid_utils.dart';
import 'package:zegoliveroom_plugin/zegoliveroom_plugin.dart';

class ZegoUtils {
  static final ZegoUtils _zegoUtils = ZegoUtils._internal();

  factory ZegoUtils() {
    return _zegoUtils;
  }

  ZegoUtils._internal() {
    // 设置是否启用测试环境
    ZegoLiveRoomPlugin.setUseTestEnv(true);

    // 设置是否打开调试信息
    ZegoLiveRoomPlugin.setVerbose(true);

    // 设置是否使用 Platform View 渲染
    ZegoLiveRoomPlugin.enablePlatformView(enablePlatformViewFlag);

    // 获取即构SDK版本信息
    ZegoLiveRoomPlugin.getSdkVersion().then((version) {
      print('[SDK Version] $version');
    });
  }

  /// 是否使用Platform View渲染
  bool enablePlatformViewFlag = false;

  /// 推流Platform View的ID
  int _publisherViewId = -1;

  BuildContext _context;

  /// TODO 视频大小参数
  int screenWidthPx;
  int screenHeightPx;

  /// 流ID集合
  List<String> streamIdList = List<String>();

  /// 流属性Map
  Map<String, ZegoStreamInfo> streamInfoMap = Map<String, ZegoStreamInfo>();

  /// 渲染层ID Map
  Map<String, int> textureIdMap = Map<String, int>();

  /// 视图ID Map
  Map<String, int> viewIdMap = Map<String, int>();

  /// 视图Widget Map
  Map<String, Widget> viewMap = Map<String, Widget>();

  /// 通知UI层刷新的方法
  Function(bool refresh) _refreshFunc;

  /// 初始化SDK，相应配置设置
  void initSDK(BuildContext context, int appId, String appSign) {
    this._context = context;
    // TODO 视频大小参数
    screenWidthPx = 100 * MediaQuery.of(_context).devicePixelRatio.toInt();
    screenHeightPx = 100 * MediaQuery.of(_context).devicePixelRatio.toInt();
    ZegoLiveRoomPlugin.initSDK(appId, appSign).then((errorCode) {
      if (errorCode == ZegoErrorCode.kOK) {
        print('初始化SDK成功');
      } else {
        // TODO 初始化失败的处理，一般为客户端网络问题导致，SDK内部会做重试工作，开发者也可在此做有限次数初始化重试，或给出友好的交互提示
        // 当初始化失败时释放SDK, 避免下次再次初始化SDK会收不到回调
        ZegoLiveRoomPlugin.uninitSDK();
        print('初始化SDK失败');
      }
    });
  }

  /// 开始视频会议
  void startVideoConference({
    @required String userId,
    @required String username,
    @required String roomId,
    @required String roomName,
    @required String title,
    @required Function(bool refresh) refreshFunc,
  }) async {
    this._refreshFunc = refreshFunc;

    // 登录房间前，先检查照相机与麦克风权限
    Authorization authorization = await PermissionUtils.checkAuthorization();
    // 权限对象为null，表明当前运行系统下无需进行动态检查权限（如Android 6.0以下系统）
    if (authorization == null) {
      _loginRoom(userId: userId, username: username, roomId: roomId, roomName: roomName, title: title);
    }
    if (!authorization.camera || !authorization.microphone) {
      // 未允许授权，弹窗提示并引导用户开启
      DialogUtils.showSettingsLink(_context);
    } else {
      // 授权完成，允许登录房间
      _loginRoom(userId: userId, username: username, roomId: roomId, roomName: roomName, title: title);
    }
  }

  /// 登录房间
  void _loginRoom({
    @required String userId,
    @required String username,
    @required String roomId,
    @required String roomName,
    @required String title,
  }) async {
    // 调用登录房间之前，必须先调用setUser
    bool success = await ZegoLiveRoomPlugin.setUser(userId, username);
    if (!success) {
      print('设置用户方法失败');
    }
    // 设置房间监听回调
    ZegoLiveRoomPlugin.registerRoomCallback(onStreamUpdated: _onStreamUpdated);
    // 登录房间
    ZegoLiveRoomPlugin.loginRoom(roomId, roomName, ZegoRoomRole.ROOM_ROLE_ANCHOR).then((result) {
      // 0代表无错误
      if (result.errorCode == ZegoErrorCode.kOK) {
        // 1.推流操作
        String publisherStreamId = UuidUtils.getUuid();
        // 创建预览
        if (!enablePlatformViewFlag) {
          ZegoLiveRoomPublisherPlugin.createPreviewRenderer(screenWidthPx, screenHeightPx).then((textureID) {
            print('创建推流预览渲染器，ID: $textureID');
            _changeDataSource(roomId, publisherStreamId, true, textureId: textureID);
          });
          ZegoLiveRoomPublisherPlugin.setPreviewViewMode(ZegoViewMode.ZegoRendererScaleAspectFill);
          ZegoLiveRoomPublisherPlugin.startPreview();
        } else {
          Widget widget = ZegoLiveRoomPublisherPlugin.createPreviewPlatformView((int viewID) {
            this._publisherViewId = viewID;
            _changeDataSource(roomId, publisherStreamId, true, viewId: viewID);
            ZegoLiveRoomPublisherPlugin.setPreviewView(viewID);
            ZegoLiveRoomPublisherPlugin.setPlatformViewPreviewViewMode(ZegoViewMode.ZegoRendererScaleAspectFill);
            ZegoLiveRoomPublisherPlugin.startPreview();
          });
          viewMap[publisherStreamId] = widget;
        }
        // 开始推流
        ZegoLiveRoomPublisherPlugin.registerPublisherCallback(onPublishStateUpdate: _onPublishStateUpdate);
        ZegoLiveRoomPublisherPlugin.startPublishing(publisherStreamId, title, ZegoPublishFlag.ZEGO_JOIN_PUBLISH);

        // 2.拉流操作
        ZegoLiveRoomPlayerPlugin.registerPlayerCallback(onPlayStateUpdate: _onPlayStateUpdate);
        List<ZegoStreamInfo> streamList = result.streamList;
        for (ZegoStreamInfo streamInfo in streamList) {
          if (!enablePlatformViewFlag) {
            // 创建拉流渲染器
            ZegoLiveRoomPlayerPlugin.createPlayViewRenderer(streamInfo.streamID, screenWidthPx, screenHeightPx)
                .then((textureID) {
              print('创建拉流预览渲染器，ID: $textureID');
              _changeDataSource(roomId, streamInfo.streamID, true, streamInfo: streamInfo, textureId: textureID);
            });
          } else {
            // 创建拉流渲染器
            Widget widget = ZegoLiveRoomPlayerPlugin.createPlayPlatformView(streamInfo.streamID, (viewId) {
              print('创建拉流Platform View，ID: $viewId');
              _changeDataSource(roomId, streamInfo.streamID, true, streamInfo: streamInfo, viewId: viewId);
            });
            viewMap[streamInfo.streamID] = widget;
          }

          // 播放直播流
          ZegoLiveRoomPlayerPlugin.startPlayingStream(streamInfo.streamID).then((success) {
            ZegoLiveRoomPlayerPlugin.setViewMode(streamInfo.streamID, ZegoViewMode.ZegoRendererScaleAspectFill);
          });
        }
      } else {
        // TODO 登录失败的处理，一般为客户端网络问题导致，SDK内部会做重试工作，开发者也可在此做有限次数的登录重试，或给出友好的交互提示，提示用户重新登录房间
        print('登录房间失败');
      }
    });
  }

  /// 退出视频会议
  void exitVideoConference() {
    // 停止推流
    ZegoLiveRoomPublisherPlugin.stopPublishing();
    // 停止推流本地渲染
    ZegoLiveRoomPublisherPlugin.stopPreview();
    if (!enablePlatformViewFlag) {
      // 销毁预览渲染器
      ZegoLiveRoomPublisherPlugin.destroyPreviewRenderer();
    } else {
      // 销毁预览 Platform View
      ZegoLiveRoomPublisherPlugin.removePreviewPlatformView(_publisherViewId);
    }
    // 注销推流监听回调
    ZegoLiveRoomPublisherPlugin.unregisterPublisherCallback();

    streamIdList.forEach((streamId) {
      // 停止拉流
      ZegoLiveRoomPlayerPlugin.stopPlayingStream(streamId);
      if (!enablePlatformViewFlag) {
        // 销毁拉流渲染器
        ZegoLiveRoomPlayerPlugin.destroyPlayViewRenderer(streamId);
      } else {
        // 移除渲染View
        ZegoLiveRoomPlayerPlugin.removePlayPlatformView(viewIdMap[streamId]);
      }
      // 移除拉流监听回调
      ZegoLiveRoomPlayerPlugin.unregisterPlayerCallback();
    });

    // 退出房间
    ZegoLiveRoomPlugin.logoutRoom();
    // 注销房间监听回调
    ZegoLiveRoomPlugin.unregisterRoomCallback();
  }

  /// 注销SDK
  void uninitSDK() {
    ZegoLiveRoomPlugin.uninitSDK();
  }

  /// 房间内推流变化的回调，开发者应监听此回调来在视频通话场景中拉别人的流或停拉别人的流
  /// [type] 流增加还是流减少的类型
  /// [listStream] 变化的流列表
  /// [roomID] 房间id
  void _onStreamUpdated(int type, List<ZegoStreamInfo> streamList, String roomID) {
    // 当登陆房间成功后，如果房间内中途有人推流或停止推流。房间内其他人就能通过该回调收到流更新通知。
    for (ZegoStreamInfo streamInfo in streamList) {
      if (type == ZegoStreamUpdateType.STREAM_ADD) {
        if (!enablePlatformViewFlag) {
          ZegoLiveRoomPublisherPlugin.createPreviewRenderer(screenWidthPx, screenHeightPx).then((textureID) {
            print('创建推流预览渲染器，ID: $textureID');
            _changeDataSource(roomID, streamInfo.streamID, true, textureId: textureID);
          });
          ZegoLiveRoomPublisherPlugin.setPreviewViewMode(ZegoViewMode.ZegoRendererScaleAspectFill);
          ZegoLiveRoomPublisherPlugin.startPreview();
        } else {
          // 创建拉流渲染器
          Widget widget = ZegoLiveRoomPlayerPlugin.createPlayPlatformView(streamInfo.streamID, (viewId) {
            print('创建拉流预览渲染器，ID: $viewId');
            _changeDataSource(roomID, streamInfo.streamID, true, streamInfo: streamInfo, viewId: viewId);
          });
          viewMap[streamInfo.streamID] = widget;
        }
        // 播放直播流
        ZegoLiveRoomPlayerPlugin.startPlayingStream(streamInfo.streamID).then((success) {
          ZegoLiveRoomPlayerPlugin.setViewMode(streamInfo.streamID, ZegoViewMode.ZegoRendererScaleAspectFill);
        });
      } else if (type == ZegoStreamUpdateType.STREAM_DELETE) {
        // 停止播放直播流
        ZegoLiveRoomPlayerPlugin.stopPlayingStream(streamInfo.streamID).then((success) {
          if (success) {
            print('停止播放直播流成功');
          } else {
            print('停止播放直播流失败');
          }
        });
        if (!enablePlatformViewFlag) {
          // 销毁拉流渲染器
          ZegoLiveRoomPlayerPlugin.destroyPlayViewRenderer(streamInfo.streamID);
        } else {
          // 销毁拉流渲染器
          ZegoLiveRoomPlayerPlugin.removePlayPlatformView(viewIdMap[streamInfo.streamID]);
          viewMap.remove(streamInfo.streamID);
        }
        _changeDataSource(roomID, streamInfo.streamID, false);
      }
    }
  }

  /// 推流状态更新回调
  void _onPublishStateUpdate(int stateCode, String streamID, Map<String, dynamic> info) {
    if (stateCode == ZegoErrorCode.kOK) {
      print('$streamID -> 推流成功');
    } else {
      print('$streamID -> 推流失败，错误码: $stateCode');
    }
  }

  /// 拉流状态更新回调
  void _onPlayStateUpdate(int stateCode, String streamID) {
    if (stateCode == ZegoErrorCode.kOK) {
      print('$streamID -> 拉流成功');
    } else {
      print('$streamID -> 拉流失败，错误码: $stateCode');
    }
  }

  /// 数据源操作
  void _changeDataSource(
    String roomId,
    String streamId,
    bool isAddOpt, {
    ZegoStreamInfo streamInfo,
    int viewId,
    int textureId,
  }) {
    if (isAddOpt) {
      if (streamIdList.contains(streamId)) {
        return;
      }
      streamIdList.add(streamId);
      streamInfoMap[streamId] = streamInfo;
      viewIdMap[streamId] = viewId;
      textureIdMap[streamId] = textureId;
      // 通知刷新
      _refreshFunc(true);
    } else {
      if (!streamIdList.contains(streamId)) {
        return;
      }
      streamIdList.remove(streamId);
      streamInfoMap.remove(streamId);
      viewIdMap.remove(streamId);
      textureIdMap.remove(streamId);
      // 通知刷新
      _refreshFunc(true);
    }
  }
}
