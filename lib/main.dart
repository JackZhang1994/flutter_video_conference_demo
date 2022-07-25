import 'package:flutter/material.dart';
import 'package:flutter_jigou/utils/widget_utils.dart';
import 'package:flutter_jigou/utils/zego_utils.dart';
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
  /// TODO 在此处修改用户： 张:1； 葛：2； 王：3
  int user = 1;

  /// 填入实际从即构官网获取到的AppID
  final int appID = 436733312;

  /// 填入实际从即构官网获取到的AppSign
  final String appSign =
      '**** **** ****';

  /// 即构SDK初始化
  ZegoUtils _zegoUtils;

  /// 流ID集合
  List<String> streamIdList = List<String>();

  /// 流属性Map
  Map<String, ZegoStreamInfo> streamInfoMap = Map<String, ZegoStreamInfo>();

  /// 视图ID Map
  Map<String, int> viewIdMap = Map<String, int>();

  /// 视图Widget Map
  Map<String, Widget> viewMap = Map<String, Widget>();

  /// 模拟房间信息
  final String roomId = '1513';
  final String roomName = '测试房间';

  /// 模拟用户信息
  String userId;
  String username;

  @override
  void initState() {
    super.initState();
    switch (user) {
      case 1:
        userId = '001';
        username = '张某某';
        break;

      case 2:
        userId = '002';
        username = '葛某某';
        break;

      case 3:
        userId = '003';
        username = '王某某';
        break;
    }
    _zegoUtils = ZegoUtils();
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () => _zegoUtils.initSDK(context, appID, appSign),
                    ),
                  ),
                  WidgetUtils.vGaps10,
                  Container(
                    width: 100,
                    height: 44,
                    child: FlatButton(
                      child: Text('2.开启视频会议'),
                      onPressed: () => _zegoUtils.startVideoConference(
                        userId: userId,
                        username: username,
                        roomId: roomId,
                        roomName: roomName,
                        title: '自定义直播名称',
                        viewWidth: 100,
                        viewHeight: 100,
                        refreshFunc: (flag) {
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  WidgetUtils.vGaps10,
                  Container(
                    width: 100,
                    height: 44,
                    child: FlatButton(
                      child: Text('3.退出视频会议'),
                      onPressed: () => _zegoUtils.exitVideoConference(),
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
    _zegoUtils.textureIdMap.values.toList().forEach((textureId) {
      list.add(Container(
        child: textureId >= 0 ? Texture(textureId: textureId) : null,
      ));
    });
    return list;
  }

  @override
  void dispose() {
    // 反初始化SDK，释放资源
    _zegoUtils.uninitSDK();
    super.dispose();
  }
}
