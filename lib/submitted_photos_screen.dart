// submitted_photos_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yolo_detect/therapy_home_screen.dart'; // Ensure this path is correct
import 'body_side.dart';
import 'dart:math' as math;

// --- TOP-LEVEL CONSTANTS AND HELPER FUNCTIONS ---

const List<List<int>> _cocoSkeletonConnections = [
  [0, 1], [0, 2], [1, 3], [2, 4],     // Face
  [5, 6], [5, 7], [7, 9], [6, 8], [8, 10], // Arms
  [5, 11], [6, 12],                    // Torso to Shoulders
  [11, 12],                           // Shoulder to Shoulder
  [11, 13], [13, 15],                  // Left Leg
  [12, 14], [14, 16]                   // Right Leg
];

/// Determines which keypoint indices are relevant for the visual overlay.
List<int> getRelevantKeypointIndices(String exerciseTitle, BodySide side) {
  switch (exerciseTitle) {
    case 'Shoulder Abduction':
    case 'Shoulder Flexion 0-90':
    case 'Shoulder Flexion 90-180':
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
    case 'Shoulder Flexion 0-90':
    case 'Shoulder Flexion 90-180':
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
    case 'Shoulder Flexion 0-90':
      return "90.0°";
    case 'Shoulder Flexion 90-180':
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
  // ... (This widget's code is unchanged)
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
                            LayoutBuilder(builder: (context, constraints) {
                              final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
                              
                              final relevantIndices = getRelevantKeypointIndices(exerciseTitle, side ?? BodySide.right);

                              return CustomPaint(
                                painter: KeypointPainter(
                                  keypoints: keypoints!,
                                  imageSize: imageSize,
                                  highlightIndices: relevantIndices,
                                ),
                              );
                            }),
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

class KeypointPainter extends CustomPainter {
  final List<KeypointData> keypoints;
  final Size imageSize;
  final List<int> highlightIndices;

  KeypointPainter({
    required this.keypoints,
    required this.imageSize,
    required this.highlightIndices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final highlightPointPaint = Paint()
      ..color = Colors.yellow
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    // A new paint for the lines that form the angle
    final angleLinePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4.0;

    // --- Draw Angle Lines ---
    // First, check if we have the three specific points needed to form an angle.
    if (highlightIndices.length == 3) {
      final p1Index = highlightIndices[0];
      final vertexIndex = highlightIndices[1];
      final p3Index = highlightIndices[2];

      // Ensure all indices are valid for the keypoints list.
      if (keypoints.length > p1Index && keypoints.length > vertexIndex && keypoints.length > p3Index) {
        final p1 = keypoints[p1Index];
        final vertex = keypoints[vertexIndex];
        final p3 = keypoints[p3Index];

        // Check confidence before drawing the lines.
        if (p1.confidence > 0.3 && vertex.confidence > 0.3 && p3.confidence > 0.3) {
          final scaledP1 = Offset(p1.offset.dx * size.width, p1.offset.dy * size.height);
          final scaledVertex = Offset(vertex.offset.dx * size.width, vertex.offset.dy * size.height);
          final scaledP3 = Offset(p3.offset.dx * size.width, p3.offset.dy * size.height);

          // Draw the two lines that form the angle with the vertex in the middle.
          canvas.drawLine(scaledP1, scaledVertex, angleLinePaint);
          canvas.drawLine(scaledVertex, scaledP3, angleLinePaint);
        }
      }
    }

    // --- Draw Highlighted Keypoints ---
    // Draw the yellow dots on top of the lines for better visibility.
    for (final index in highlightIndices) {
      if (keypoints.length > index) {
        final kp = keypoints[index];
        if (kp.confidence < 0.3) continue;

        final scaledOffset = Offset(kp.offset.dx * size.width, kp.offset.dy * size.height);
        canvas.drawPoints(PointMode.points, [scaledOffset], highlightPointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KeypointPainter oldDelegate) {
    return oldDelegate.keypoints != keypoints || oldDelegate.imageSize != imageSize || oldDelegate.highlightIndices != highlightIndices;
  }
}