import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

// Import the KeypointData class
import 'therapy_home_screen.dart';

class KeypointPainter extends CustomPainter {
   /// The list of keypoint data to draw.
   final List<KeypointData> keypoints;
   // The size of the image, to correctly scale the points.
   final Size imageSize;

   // FIX: Updated the constructor to accept List<KeypointData>
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

     // Filter out keypoints with a low confidence score
     final List<Offset> highConfidencePoints = [];
     for (final kp in keypoints) {
        if (kp.confidence >= 0.3) {
          highConfidencePoints.add(Offset(kp.offset.dx * size.width, kp.offset.dy * size.height));
        }
     }

     // Draw each keypoint as a dot, after scaling
     canvas.drawPoints(PointMode.points, highConfidencePoints, pointPaint);
   }

   @override
   bool shouldRepaint(covariant KeypointPainter oldDelegate) {
     // Repaint only if the keypoints or image size have changed.
     // The comparison needs to be updated to account for the new data type.
     return oldDelegate.keypoints != keypoints || oldDelegate.imageSize != imageSize;
   }
}