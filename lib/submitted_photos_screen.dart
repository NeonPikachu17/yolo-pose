import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'body_side.dart';
import 'dart:math' as math;

// New data class to hold keypoint and confidence
class KeypointData {
  final Offset offset;
  final double confidence;
  KeypointData(this.offset, this.confidence);
}

// Helper function to convert raw data to KeypointData objects
List<KeypointData>? _convertKeypointsToData(List<Map<String, double>>? keypoints) {
  if (keypoints == null) return null;
  final List<KeypointData> keypointDataList = [];
  for (var point in keypoints) {
    if (point['x'] != null && point['y'] != null && point['confidence'] != null) {
      keypointDataList.add(KeypointData(
          Offset(point['x']!, point['y']!),
          point['confidence']!
      ));
    }
  }
  return keypointDataList.isNotEmpty ? keypointDataList : null;
}

// --- For Calculations  ---
List<int> getRelevantKeypointIndices(String exerciseTitle, BodySide side) {
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
      return [];
  }
}

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

          // Correct the type cast here
          final rawStartKeypoints = data['start_keypoints'] as List<Map<String, double>>?;
          final rawEndKeypoints = data['end_keypoints'] as List<Map<String, double>>?;

          // Convert to KeypointData before passing to widgets
          final startKeypoints = _convertKeypointsToData(rawStartKeypoints);
          final endKeypoints = _convertKeypointsToData(rawEndKeypoints);

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

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
          ),
        ),
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
                    ? FutureBuilder<ui.Image>(
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
                              Image.file(imageFile!, fit: BoxFit.cover),
                              if (keypoints != null && keypoints!.isNotEmpty)
                                LayoutBuilder(builder: (context, constraints) {
                                  return CustomPaint(
                                    painter: KeypointPainter(
                                      keypoints: keypoints!,
                                      originalImageSize: originalSize,
                                      displaySize: Size(constraints.maxWidth, constraints.maxHeight),
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
  final Size originalImageSize;
  final Size displaySize;
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

    final double scaleX = displaySize.width / originalImageSize.width;
    final double scaleY = displaySize.height / originalImageSize.height;

    Offset _getScaledOffset(KeypointData kp) {
      return Offset(
        kp.offset.dx * originalImageSize.width * scaleX,
        kp.offset.dy * originalImageSize.height * scaleY,
      );
    }
    
    if (highlightIndices.length == 3) {
      final p1Index = highlightIndices[0];
      final vertexIndex = highlightIndices[1];
      final p3Index = highlightIndices[2];

      if (keypoints.length > p1Index && keypoints.length > vertexIndex && keypoints.length > p3Index) {
        final p1 = keypoints[p1Index];
        final vertex = keypoints[vertexIndex];
        final p3 = keypoints[p3Index];

        if (p1.confidence > 0.3 && vertex.confidence > 0.3 && p3.confidence > 0.3) {
          final scaledP1 = _getScaledOffset(p1);
          final scaledVertex = _getScaledOffset(vertex);
          final scaledP3 = _getScaledOffset(p3);

          canvas.drawLine(scaledP1, scaledVertex, angleLinePaint);
          canvas.drawLine(scaledVertex, scaledP3, angleLinePaint);
        }
      }
    }

    for (final index in highlightIndices) {
      if (keypoints.length > index) {
        final kp = keypoints[index];
        if (kp.confidence < 0.3) continue;
        
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