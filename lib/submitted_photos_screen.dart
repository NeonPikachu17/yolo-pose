// submitted_photos_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui; // Import with a prefix to avoid conflicts
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yolo_detect/therapy_home_screen.dart';
import 'body_side.dart';
import 'dart:math' as math;

// --- TOP-LEVEL CONSTANTS AND HELPER FUNCTIONS ---
/// Determines which keypoint indices are relevant for the visual overlay.
List<int> getRelevantKeypointIndices(String exerciseTitle, BodySide side) {
  switch (exerciseTitle) {
    case 'Shoulder Abduction':
      return side == BodySide.left ? [11, 5, 7] : [12, 6, 8];
    case 'Shoulder Flexion 0°-90°': // FIXED: Corrected title here to match the image
      return side == BodySide.left ? [11, 5, 7] : [12, 6, 8];
    case 'Shoulder Flexion 90°-180°': // FIXED: Corrected title here to match the image
      return side == BodySide.left ? [11, 5, 7] : [12, 6, 8];
    case 'Hand to Lumbar Spine':
      return side == BodySide.left ? [5, 7, 9] : [6, 8, 10];
    default:
      return [];
  }
}

/// Calculates the angle between three points.
double _calculateAngle(KeypointData p1, KeypointData p2, KeypointData p3) {
  if (p1.confidence < 0.3 || p2.confidence < 0.3 || p3.confidence < 0.3) return 0.0;
  
  double angle = (math.atan2(p3.offset.dy - p2.offset.dy, p3.offset.dx - p2.offset.dx) -
                  math.atan2(p1.offset.dy - p2.offset.dy, p1.offset.dx - p2.offset.dx)) * 180 / math.pi;
  angle = angle.abs();
  if (angle > 180) {
    angle = 360 - angle;
  }
  return angle;
}

/// Returns the keypoint indices needed for an angle calculation [p1, vertex, p3].
List<int>? _getAngleKeypointIndices(String exerciseTitle, BodySide side) {
  switch (exerciseTitle) {
    case 'Shoulder Abduction':
      return side == BodySide.left ? [11, 5, 7] : [12, 6, 8];
    case 'Shoulder Flexion 0°-90°':
      return side == BodySide.left ? [11, 5, 7] : [12, 6, 8];
    case 'Shoulder Flexion 90°-180°':
      return side == BodySide.left ? [11, 5, 7] : [12, 6, 8];
    case 'Hand to Lumbar Spine':
      return side == BodySide.left ? [5, 7, 9] : [6, 8, 10];
    default:
      return null;
  }
}

/// Returns the target goal for a given exercise.
String _getMovementGoal(String exerciseTitle) {
  switch (exerciseTitle) {
    case 'Shoulder Abduction':
      return "90.0°";
    case 'Shoulder Flexion 0°-90°':
      return "90.0°";
    case 'Shoulder Flexion 90°-180°':
      return "170.0°";
    case 'Hand to Lumbar Spine':
      return "<= 70.0°";
    default:
      return "N/A";
  }
}


// --- WIDGETS ---

class SubmittedPhotosScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> exerciseData;

  const SubmittedPhotosScreen({super.key, required this.exerciseData});
  
  // NOTE: The helper functions have been moved outside this class.

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
                  _KeyMetricsCard(
                    exerciseTitle: exerciseTitle,
                    side: side,
                    startKeypoints: startKeypoints,
                    endKeypoints: endKeypoints,
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

/// A card that displays the key performance metrics of an exercise.
class _KeyMetricsCard extends StatelessWidget {
  final String exerciseTitle;
  final BodySide? side;
  final List<KeypointData>? startKeypoints;
  final List<KeypointData>? endKeypoints;

  const _KeyMetricsCard({
    required this.exerciseTitle,
    this.side,
    this.startKeypoints,
    this.endKeypoints,
  });

  @override
  Widget build(BuildContext context) {
    if (startKeypoints == null || endKeypoints == null || side == null) {
      return const SizedBox.shrink();
    }

    final indices = _getAngleKeypointIndices(exerciseTitle, side!);
    if (indices == null) return const SizedBox.shrink();

    // FIXED: Corrected the typo here (_calculateAngl -> _calculateAngle)
    final startAngle = _calculateAngle(startKeypoints![indices[0]], startKeypoints![indices[1]], startKeypoints![indices[2]]);
    final endAngle = _calculateAngle(endKeypoints![indices[0]], endKeypoints![indices[1]], endKeypoints![indices[2]]);
    final rangeOfMotion = (endAngle - startAngle).abs();
    final goal = _getMovementGoal(exerciseTitle);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Key Metrics",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const Divider(height: 20),
          _MetricRow(label: "Range of Motion", value: "${rangeOfMotion.toStringAsFixed(1)}°"),
          const SizedBox(height: 12),
          _MetricRow(label: "Start Angle", value: "${startAngle.toStringAsFixed(1)}°"),
          const SizedBox(height: 12),
          _MetricRow(label: "End Angle", value: "${endAngle.toStringAsFixed(1)}°"),
          const SizedBox(height: 12),
          _MetricRow(label: "Movement Goal", value: goal),
        ],
      ),
    );
  }
}

/// A helper widget for displaying a single metric row.
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      // The `mainAxisAlignment` is no longer needed as Expanded handles the layout.
      children: [
        // Wrap the label with Expanded.
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
          ),
        ),
        // The value stays the same.
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }
}

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

  // NEW: A helper function to get the image dimensions
  Future<ui.Image> _loadImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
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
                    ? FutureBuilder<ui.Image>( // NEW: Use FutureBuilder to get image size
                        future: _loadImage(imageFile!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final originalImage = snapshot.data!;
                          final originalSize = Size(originalImage.width.toDouble(), originalImage.height.toDouble());
                          
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // The image itself
                              Image.file(imageFile!, fit: BoxFit.cover),
                              
                              if (keypoints != null && keypoints!.isNotEmpty)
                                LayoutBuilder(builder: (context, constraints) {
                                  // Pass the original size to the painter
                                  return CustomPaint(
                                    painter: KeypointPainter(
                                      keypoints: keypoints!,
                                      originalImageSize: originalSize, // NEW: Pass the correct size
                                      displaySize: Size(constraints.maxWidth, constraints.maxHeight), // NEW: Pass the widget's size
                                      highlightIndices: getRelevantKeypointIndices(exerciseTitle, side ?? BodySide.right),
                                    ),
                                  );
                                }),
                            ],
                          );
                        },
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

class KeypointPainter extends CustomPainter {
  final List<KeypointData> keypoints;
  final Size originalImageSize; // NEW: The size of the original image
  final Size displaySize; // NEW: The size of the widget on screen
  final List<int> highlightIndices;

  KeypointPainter({
    required this.keypoints,
    required this.originalImageSize,
    required this.displaySize,
    required this.highlightIndices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final highlightPointPaint = Paint()
      ..color = Colors.yellow
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    final angleLinePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4.0;

    // Calculate scaling factors
    final double scaleX = displaySize.width / originalImageSize.width;
    final double scaleY = displaySize.height / originalImageSize.height;

    // Helper function to scale a keypoint
    Offset _getScaledOffset(KeypointData kp) {
      return Offset(
        kp.offset.dx * originalImageSize.width * scaleX,
        kp.offset.dy * originalImageSize.height * scaleY,
      );
    }
    
    // ... (rest of the paint method, using the new scaled offsets)

    // --- Draw Angle Lines ---
    if (highlightIndices.length == 3) {
      final p1Index = highlightIndices[0];
      final vertexIndex = highlightIndices[1];
      final p3Index = highlightIndices[2];

      if (keypoints.length > p1Index && keypoints.length > vertexIndex && keypoints.length > p3Index) {
        final p1 = keypoints[p1Index];
        final vertex = keypoints[vertexIndex];
        final p3 = keypoints[p3Index];

        if (p1.confidence > 0.3 && vertex.confidence > 0.3 && p3.confidence > 0.3) {
          // Use the new scaling logic
          final scaledP1 = _getScaledOffset(p1);
          final scaledVertex = _getScaledOffset(vertex);
          final scaledP3 = _getScaledOffset(p3);

          canvas.drawLine(scaledP1, scaledVertex, angleLinePaint);
          canvas.drawLine(scaledVertex, scaledP3, angleLinePaint);
        }
      }
    }

    // --- Draw Highlighted Keypoints ---
    for (final index in highlightIndices) {
      if (keypoints.length > index) {
        final kp = keypoints[index];
        if (kp.confidence < 0.3) continue;
        
        // Use the new scaling logic
        final scaledOffset = _getScaledOffset(kp);
        canvas.drawPoints(ui.PointMode.points, [scaledOffset], highlightPointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KeypointPainter oldDelegate) {
    return oldDelegate.keypoints != keypoints || oldDelegate.originalImageSize != originalImageSize || oldDelegate.highlightIndices != highlightIndices;
  }
}