// submitted_photos_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yolo_detect/therapy_home_screen.dart'; // Import the new KeypointData class
import 'body_side.dart';

// The universal map for COCO keypoints and skeleton.
const Map<String, List<List<int>>> _cocoSkeleton = {
 'connections': [
  [0, 1], [0, 2], [1, 3], [2, 4], // Face (eyes, ears, nose)
  [5, 6], [5, 7], [7, 9], [6, 8], [8, 10], // Arms
  [5, 11], [6, 12], // Torso
  [11, 12], [11, 13], [13, 15], [12, 14], [14, 16], // Legs and Hips
 ],
};

class SubmittedPhotosScreen extends StatelessWidget {
 final Map<String, Map<String, dynamic>> exerciseData;

 const SubmittedPhotosScreen({super.key, required this.exerciseData});

 @override
 Widget build(BuildContext context) {
  final exercisesWithPhotos = exerciseData.entries
    .where((e) => e.value.containsKey('start') || e.value.containsKey('end'))
    .toList();

  return Scaffold(
   backgroundColor: Colors.white,
   appBar: AppBar(title: const Text("Analysis Results")),
   body: ListView.builder(
    padding: const EdgeInsets.all(16.0),
    itemCount: exercisesWithPhotos.length,
    itemBuilder: (context, index) {
     final entry = exercisesWithPhotos[index];
     final exerciseTitle = entry.key;
     final data = entry.value;

     final startImage = data['start'] as File?;
     final endImage = data['end'] as File?;
     final score = data['score'] as int?;
     final results = data['results'] as String?;
     final startKeypoints = data['start_keypoints'] as List<KeypointData>?;
     final endKeypoints = data['end_keypoints'] as List<KeypointData>?;
     final side = data['side'] as BodySide?;

     return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(20),
       side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
       padding: const EdgeInsets.all(16.0),
       child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
           Expanded(
            child: Text(
             exerciseTitle,
             style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
           ),
           if (score != null)
            Text(
             "$score pts",
             style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
             ),
            )
          ],
         ),
         if (results != null) ...[
          const Divider(height: 24),
          Text(results, style: GoogleFonts.poppins(fontSize: 15)),
         ],
         const SizedBox(height: 12),
         Row(
          children: [
           _PhotoDisplay(label: "START", imageFile: startImage, keypoints: startKeypoints, exerciseTitle: exerciseTitle, side: side),
           const SizedBox(width: 16),
           _PhotoDisplay(label: "END", imageFile: endImage, keypoints: endKeypoints, exerciseTitle: exerciseTitle, side: side),
          ],
         ),
                  const SizedBox(height: 20),
                  _DebugKeypointData(
                    label: "START Keypoint Data",
                    keypoints: startKeypoints,
                  ),
                  _DebugKeypointData(
                    label: "END Keypoint Data",
                    keypoints: endKeypoints,
                  ),
        ],
       ),
      ),
     );
    },
   ),
  );
 }
}

/// A widget to display a photo with a label and optional keypoint overlays.
class _PhotoDisplay extends StatelessWidget {
 final String label;
 final File? imageFile;
 final List<KeypointData>? keypoints;
 final String exerciseTitle;
 final BodySide? side;

 const _PhotoDisplay({
  required this.label,
  this.imageFile,
  this.keypoints,
  required this.exerciseTitle,
  this.side,
 });

 @override
 Widget build(BuildContext context) {
  final List<List<int>>? connections = null;

  return Expanded(
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
     const SizedBox(height: 4),
     AspectRatio(
      aspectRatio: 1.0,
      child: Container(
       decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
       ),
       child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageFile != null
          ? Stack(
            fit: StackFit.expand,
            children: [
             Image.file(imageFile!, fit: BoxFit.cover),
             if (keypoints != null && keypoints!.isNotEmpty)
              LayoutBuilder(
               builder: (context, constraints) {
                final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
                return CustomPaint(
                 painter: KeypointPainter(
                  keypoints: keypoints!,
                  imageSize: imageSize,
                 ),
                );
               }
              ),
            ],
           )
          : const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey)),
       ),
      ),
     ),
    ],
   ),
  );
 }
}

/// A widget for displaying debug keypoint data in the UI.
class _DebugKeypointData extends StatelessWidget {
  final String label;
  final List<KeypointData>? keypoints;
  
  const _DebugKeypointData({
    required this.label,
    required this.keypoints,
  });

  @override
  Widget build(BuildContext context) {
    if (keypoints == null) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatKeypoints(keypoints!),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKeypoints(List<KeypointData> keypoints) {
    final buffer = StringBuffer();
    for (int i = 0; i < keypoints.length; i++) {
      final kp = keypoints[i];
      buffer.write(
        'Keypoint $i (x: ${kp.offset.dx.toStringAsFixed(2)}, '
        'y: ${kp.offset.dy.toStringAsFixed(2)}, '
        'conf: ${kp.confidence.toStringAsFixed(2)})\n',
      );
    }
    return buffer.toString();
  }
}


/// The painter for drawing keypoints and lines on the canvas.
class KeypointPainter extends CustomPainter {
 final List<KeypointData> keypoints;
 final Size imageSize;

 KeypointPainter({required this.keypoints, required this.imageSize});

 @override
 void paint(Canvas canvas, Size size) {
  // Define the style for the points (dots)
  final pointPaint = Paint()
   ..color = Colors.red
   ..strokeCap = StrokeCap.round
   ..strokeWidth = 8.0; // Dot size
    
    // Define the text style for the labels
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

  // Filter out keypoints with a low confidence score
  final List<KeypointData> highConfidencePoints = [];
  for (final kp in keypoints) {
   if (kp.confidence >= 0.3) {
    highConfidencePoints.add(kp);
   }
  }

  // Draw each keypoint as a dot, after scaling
  for (int i = 0; i < highConfidencePoints.length; i++) {
      final kp = highConfidencePoints[i];
      final scaledOffset = Offset(kp.offset.dx * size.width, kp.offset.dy * size.height);
      
      // Draw the point
      canvas.drawPoints(PointMode.points, [scaledOffset], pointPaint);
      
      // Draw the keypoint index number next to it
      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle,
      );
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(canvas, scaledOffset.translate(8, -8));
    }
 }

 @override
 bool shouldRepaint(covariant KeypointPainter oldDelegate) {
  return oldDelegate.keypoints != keypoints || oldDelegate.imageSize != imageSize;
 }
}