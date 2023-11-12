import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'box_painter.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final MethodChannel _channel = MethodChannel('camera_channel');
  List<BoxModel> boxes = [];

  @override
  void initState() {
    super.initState();

    channelInit();
  }

  Future<void> channelInit() async {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'receiveCameraData') {
        final Map outerMap = call.arguments; // arguments를 맵으로 변환
        if (outerMap.keys.isNotEmpty) {
          boxes = [];
        }
        for (var key in outerMap.keys) {
          final Map boundingBox = outerMap[key]; // 각 키에 대해 내부 맵을 가져옵니다.
          final double x = boundingBox['x'];
          final double y = boundingBox['y'];
          final double width = boundingBox['width'];
          final double height = boundingBox['height'];
          final String label = boundingBox['label'];
          final double confidence = boundingBox['confidence'];
          // print('result: $x $y $width $height $label $confidence');

          final double screenWidth = MediaQuery.of(context).size.width;
          final double screenHeight = MediaQuery.of(context).size.height;

          final double rectX = y * screenWidth;
          final double rectY = x * screenHeight;
          final double rectWidth = height * screenWidth;
          final double rectHeight = width * screenHeight;

          setState(() {
            boxes.add(
              BoxModel(
                rect: Rect.fromLTWH(rectX, rectY, rectWidth, rectHeight),
                // rect: Rect.fromLTWH(x, y, width, height),
                label: label,
                confidence: confidence,
              ),
            );
          });
        }
      }
    });
    _channel.invokeMethod('triggerCamera');
  }

  @override
  Widget build(BuildContext context) {
    print('boxes: $boxes');
    boxes.forEach((box) {
      print(box.rect.left);
      print(box.rect.right);
      print(box.rect.top);
      print(box.rect.bottom);
    });

    if (Platform.isIOS) {
      return Scaffold(
        body: Stack(
          children: [
            UiKitView(
              viewType: 'camera_view',
              creationParamsCodec: StandardMessageCodec(),
            ),
            CustomPaint(
              // painter: BoxPainter(boxes: boxes == null ? [] : [boxes!]),
              painter: YoloBoxPainter(boxes: boxes),
            ),
          ],
        ),
      );
    } else if (Platform.isAndroid) {
      return Scaffold(
        body: Stack(
          children: [
            AndroidView(
              viewType: 'camera_view',
              onPlatformViewCreated: onPlatformViewCreated,
              creationParamsCodec: const StandardMessageCodec(),
            ),
            CustomPaint(
              // painter: BoxPainter(boxes: boxes == null ? [] : [boxes!]),
              painter: YoloBoxPainter(boxes: boxes),
            ),
          ],
        ),
      );
    } else {
      return Container();
    }
  }

  void onPlatformViewCreated(int viewId) {
    setState(() {
      print('🔥View Id: $viewId');
    });
  }
}
