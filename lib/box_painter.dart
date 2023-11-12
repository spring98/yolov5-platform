import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

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

class YoloBoxPainter extends CustomPainter {
  final List<BoxModel> boxes;

  YoloBoxPainter({required this.boxes});

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
