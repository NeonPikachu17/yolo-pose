import 'package:flutter/material.dart';
import 'dart:ui';

class KeypointPainter extends CustomPainter {
  /// The list of normalized keypoint coordinates to draw.
  final List<Offset> keypoints;
  // The size of the image, to correctly scale the points.
  final Size imageSize;

  KeypointPainter({required this.keypoints, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Define the style for the points (dots)
    final pointPaint = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8.0; // Dot size

    // Define the style for the lines
    final linePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 3.0;

    // Draw each keypoint as a dot
    for (final point in keypoints) {
      // Scale the normalized coordinates to the actual widget size
      final canvasPoint = Offset(point.dx * size.width, point.dy * size.height);
      
      // --- FIX IS HERE ---
      // Change PaintingStyle.fill to PointMode.points
      canvas.drawPoints(PointMode.points, [canvasPoint], pointPaint);
    }

    // --- Example: Draw lines connecting the points ---
    // This logic depends on which points you want to connect (e.g., elbow-to-wrist).
    // For this example, we'll just connect them in order.
    for (int i = 0; i < keypoints.length - 1; i++) {
      final startPoint = Offset(keypoints[i].dx * size.width, keypoints[i].dy * size.height);
      final endPoint = Offset(keypoints[i + 1].dx * size.width, keypoints[i + 1].dy * size.height);
      canvas.drawLine(startPoint, endPoint, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant KeypointPainter oldDelegate) {
    // Repaint only if the keypoints or image size have changed.
    return oldDelegate.keypoints != keypoints || oldDelegate.imageSize != imageSize;
  }
}