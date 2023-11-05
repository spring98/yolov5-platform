import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

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
    // print('boxes: $boxes');
    return Scaffold(
      body: Stack(
        children: [
          AndroidView(
            viewType: 'camera_view',
            onPlatformViewCreated: onPlatformViewCreated,
            creationParamsCodec: const StandardMessageCodec(),
          )
          // UiKitView(
          //   viewType: 'camera_view',
          //   creationParamsCodec: StandardMessageCodec(),
          // ),
          // CustomPaint(
          //   // painter: BoxPainter(boxes: boxes == null ? [] : [boxes!]),
          //   painter: BoxPainter(boxes: boxes),
          // ),
        ],
      ),
    );
  }

  void onPlatformViewCreated(int viewId) {
    print('View Id: $viewId');
  }
}

class BoxModel {
  final Rect rect;
  final String label;
  final double confidence;

  BoxModel({
    required this.rect,
    required this.label,
    required this.confidence,
  });
}

class BoxPainter extends CustomPainter {
  final List<BoxModel> boxes;

  BoxPainter({required this.boxes});

  List<Color> colors = [
    // Color(0xFFF26D6F),
    // Color(0xFFF2835D),
    // Color(0xFFF39C67),
    // Color(0xFFF3B45F),
    Color(0xFFDE3E47),
    Colors.blue,
    Color(0xFF7AB974),
    Color(0xFFFFC16E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < boxes.length; i++) {
      final BoxModel box = boxes[i];
      final Paint paint = Paint()
        ..color = colors[i % 4]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(box.rect, paint);

      textPainter.text = TextSpan(
        text: '${box.label}(${box.confidence.toStringAsFixed(2)})',
        style: TextStyle(
            color: colors[i % 4], fontSize: 16, fontWeight: FontWeight.w500),
      );
      textPainter.layout();

      // Save the canvas state
      canvas.save();

      // Rotate the canvas
      canvas.translate(box.rect.left, box.rect.top);
      canvas.rotate(pi / 2);

      // Draw the text
      textPainter.paint(canvas, Offset(0, 0));

      // Restore the canvas state
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
