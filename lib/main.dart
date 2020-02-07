import 'package:flutter/material.dart';
import 'package:flutter_jigou/utils/dialog_utils.dart';
import 'package:flutter_jigou/utils/permission_utils.dart';
import 'package:flutter_jigou/utils/uuid_utils.dart';
import 'package:flutter_jigou/utils/widget_utils.dart';
import 'package:zegoliveroom_plugin/zegoliveroom_plugin.dart';

void main() => runApp(new BaseApp());

class BaseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyApp());
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// 填入实际从即构官网获取到的AppID
  final int appID = 436733312;

  /// 填入实际从即构官网获取到的AppSign
  final String appSign =
      '0xef,0x9a,0xa1,0xa1,0x77,0x86,0x55,0xbe,0x2c,0x0f,0xe2,0x15,0xf6,0x68,0xf7,0xe0,0x94,0xa9,0x70,0xf5,0x4a,0x79,0x01,0x83,0xad,0x49,0x13,0xe9,0x74,0x3a,0x1e,0xbe';

  /// 流ID集合
  List<String> streamIdList = List<String>();

  /// 流属性Map
  Map<String, ZegoStreamInfo> streamInfoMap = Map<String, ZegoStreamInfo>();

  /// 渲染器ID Map
  Map<String, int> textureIdMap = Map<String, int>();

  /// 模拟房间信息
  final String roomId = '1513';
  final String roomName = '测试房间';

  /// 模拟用户信息1
  final String userId1 = '001';
  final String username1 = '马云';

  /// 模拟用户信息2
  final String userId2 = '002';
  final String username2 = '马化腾';

  /// 渲染层宽高
  int screenWidthPx;
  int screenHeightPx;

  @override
  void initState() {
    super.initState();

    // 设置是否启用测试环境
    ZegoLiveRoomPlugin.setUseTestEnv(true);

    // 设置是否打开调试信息
    ZegoLiveRoomPlugin.setVerbose(true);

    // 设置是否使用 Platform View 渲染
    ZegoLiveRoomPlugin.enablePlatformView(false);

    // 获取即构SDK版本信息
    ZegoLiveRoomPlugin.getSdkVersion().then((version) {
      print('[SDK Version] $version');
    });
  }

  @override
  Widget build(BuildContext context) {
    screenWidthPx = MediaQuery.of(context).size.width.toInt() * MediaQuery.of(context).devicePixelRatio.toInt();
    screenHeightPx = (MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top).toInt() *
        MediaQuery.of(context).devicePixelRatio.toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zego Plugin example app'),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverGrid.count(
            crossAxisCount: 3,
            children: _renderWidgetList(),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: <Widget>[
                  Container(
                    width: 100,
                    height: 44,
                    child: FlatButton(
                      child: Text('1.初始化SDK'),
                      onPressed: _initSDK,
                    ),
                  ),
                  WidgetUtils.vGaps10,
                  Container(
                    width: 100,
                    height: 44,
                    child: FlatButton(
                      child: Text('2.设置房间监听回调'),
                      onPressed: _registerRoomCallback,
                    ),
                  ),
                  WidgetUtils.vGaps10,
                  Container(
                    width: 100,
                    height: 44,
                    child: FlatButton(
                      child: Text('3.开启视频会议'),
                      onPressed: _startVideoConference,
                    ),
                  ),
                  WidgetUtils.vGaps10,
                  Container(
                    width: 100,
                    height: 44,
                    child: FlatButton(
                      child: Text('4.退出视频会议'),
                      onPressed: _exitVideoConference,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _renderWidgetList() {
    var list = List<Widget>();
    textureIdMap.values.toList().forEach((textureId) {
      list.add(Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
        child: textureId >= 0 ? Texture(textureId: textureId) : null,
      ));
    });
    return list;
  }

  /// 初始化SDK
  void _initSDK() {
    ZegoLiveRoomPlugin.initSDK(appID, appSign).then((errorCode) {
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

  /// 设置房间监听回调
  void _registerRoomCallback() {
    ZegoLiveRoomPlugin.registerRoomCallback(onStreamUpdated: _onStreamUpdated);
  }

  /// 房间内推流变化的回调，开发者应监听此回调来在视频通话场景中拉别人的流或停拉别人的流
  /// [type] 流增加还是流减少的类型
  /// [listStream] 变化的流列表
  /// [roomID] 房间id
  void _onStreamUpdated(int type, List<ZegoStreamInfo> streamList, String roomID) {
    // 当登陆房间成功后，如果房间内中途有人推流或停止推流。房间内其他人就能通过该回调收到流更新通知。
    for (ZegoStreamInfo streamInfo in streamList) {
      if (type == ZegoStreamUpdateType.STREAM_ADD) {
        // 创建拉流渲染器
        ZegoLiveRoomPlayerPlugin.createPlayViewRenderer(streamInfo.streamID, screenWidthPx, screenHeightPx)
            .then((textureID) {
          print('创建拉流预览渲染器，ID: $textureID');
          _changeDataSource(streamInfo.streamID, true, streamInfo: streamInfo, textureId: textureID);
        });
        // 播放直播流
        ZegoLiveRoomPlayerPlugin.startPlayingStream(streamInfo.streamID).then((success) {
          ZegoLiveRoomPlayerPlugin.setViewMode(streamInfo.streamID, ZegoViewMode.ZegoRendererScaleAspectFill);
        });
      } else if (type == ZegoStreamUpdateType.STREAM_DELETE) {
        // TODO 销毁对应streamId的拉流渲染器
        // 创建拉流渲染器
        ZegoLiveRoomPlayerPlugin.destroyPlayViewRenderer(streamInfo.streamID);
        // 停止播放直播流
        ZegoLiveRoomPlayerPlugin.stopPlayingStream(streamInfo.streamID).then((success) {
          if (success) {
            print('停止播放直播流成功');
          } else {
            print('停止播放直播流失败');
          }
        });
        _changeDataSource(streamInfo.streamID, false);
      }
    }
  }

  /// 开启视频会议
  void _startVideoConference() async {
    // 登录房间前，先检查照相机与麦克风权限
    Authorization authorization = await PermissionUtils.checkAuthorization();
    // 权限对象为null，表明当前运行系统下无需进行动态检查权限（如Android 6.0以下系统）
    if (authorization == null) {
      _loginRoom();
      return;
    }
    if (!authorization.camera || !authorization.microphone) {
      // 未允许授权，弹窗提示并引导用户开启
      DialogUtils.showSettingsLink(context);
    } else {
      // 授权完成，允许登录房间
      _loginRoom();
    }
  }

  /// 登录房间
  void _loginRoom() async {
    // 调用登录房间之前，必须先调用setUser
    bool success = await ZegoLiveRoomPlugin.setUser(userId1, username1);
    if (!success) {
      print('设置用户方法失败');
      return;
    }

    // 登录房间
    ZegoLiveRoomPlugin.loginRoom(roomId, roomName, ZegoRoomRole.ROOM_ROLE_ANCHOR).then((result) {
      // 0代表无错误
      if (result.errorCode == ZegoErrorCode.kOK) {
        // 1.推流操作
        String publisherStreamId = UuidUtils.getUuid();
        // 创建预览
        ZegoLiveRoomPublisherPlugin.createPreviewRenderer(screenWidthPx, screenHeightPx).then((textureID) {
          print('创建推流预览渲染器，ID: $textureID');
          _changeDataSource(publisherStreamId, true, textureId: textureID);
        });
        ZegoLiveRoomPublisherPlugin.setPreviewViewMode(ZegoViewMode.ZegoRendererScaleAspectFill);
        ZegoLiveRoomPublisherPlugin.startPreview();
        // 开始推流
        ZegoLiveRoomPublisherPlugin.registerPublisherCallback(onPublishStateUpdate: _onPublishStateUpdate);
        ZegoLiveRoomPublisherPlugin.startPublishing(publisherStreamId, '自定义视频会议名称', ZegoPublishFlag.ZEGO_JOIN_PUBLISH);

        // 2.拉流操作
        ZegoLiveRoomPlayerPlugin.registerPlayerCallback(onPlayStateUpdate: _onPlayStateUpdate);
        List<ZegoStreamInfo> streamList = result.streamList;
        for (ZegoStreamInfo streamInfo in streamList) {
          // 创建拉流渲染器
          ZegoLiveRoomPlayerPlugin.createPlayViewRenderer(streamInfo.streamID, screenWidthPx, screenHeightPx)
              .then((textureID) {
            print('创建拉流预览渲染器，ID: $textureID');
            _changeDataSource(streamInfo.streamID, true, streamInfo: streamInfo, textureId: textureID);
          });
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

  /// 退出视频会议
  void _exitVideoConference() {
    // 停止推流
    ZegoLiveRoomPublisherPlugin.stopPublishing();
    // 停止推流本地渲染
    ZegoLiveRoomPublisherPlugin.stopPreview();
    // 注销推流监听回调
    ZegoLiveRoomPublisherPlugin.unregisterPublisherCallback();

    // 退出房间
    ZegoLiveRoomPlugin.logoutRoom();
    // 注销房间监听回调
    ZegoLiveRoomPlugin.unregisterRoomCallback();
  }

  /// 数据源操作
  void _changeDataSource(String streamId, bool isAddOpt, {ZegoStreamInfo streamInfo, int textureId}) {
    if (isAddOpt) {
      if (streamIdList.contains(streamId)) {
        return;
      }
      streamIdList.add(streamId);
      streamInfoMap[streamId] = streamInfo;
      textureIdMap[streamId] = textureId;
      setState(() {});
    } else {
      if (!streamIdList.contains(streamId)) {
        return;
      }
      streamIdList.remove(streamId);
      streamInfoMap.remove(streamId);
      textureIdMap.remove(streamId);
      setState(() {});
    }
  }

  @override
  void dispose() {
    // 反初始化SDK，释放资源
    ZegoLiveRoomPlugin.uninitSDK();
    super.dispose();
  }
}
