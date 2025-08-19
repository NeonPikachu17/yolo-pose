// submitted_photos_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// MODIFIED: This map now defines both the points to highlight
// and the lines that should connect them for each exercise.
const Map<String, Map<String, dynamic>> _exerciseVisualizationData = {
  'Shoulder Abduction': {
    'points': [6, 8, 12], // R_Shoulder, R_Elbow, R_Hip
    'connections': [[12, 6], [6, 8]], // Connect Hip-Shoulder and Shoulder-Elbow
  },
  'Hand to Lumbar Spine': {
    'points': [6, 8, 10], // R_Shoulder, R_Elbow, R_Wrist
    'connections': [[6, 8], [8, 10]], // Connect Shoulder-Elbow and Elbow-Wrist
  },
  // Add other exercises here
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
          final startKeypoints = data['start_keypoints'] as List<Offset>?;
          final endKeypoints = data['end_keypoints'] as List<Offset>?;

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
                      _PhotoDisplay(label: "START", imageFile: startImage, keypoints: startKeypoints, exerciseTitle: exerciseTitle),
                      const SizedBox(width: 16),
                      _PhotoDisplay(label: "END", imageFile: endImage, keypoints: endKeypoints, exerciseTitle: exerciseTitle),
                    ],
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
  final List<Offset>? keypoints;
  final String exerciseTitle;

  const _PhotoDisplay({
    required this.label,
    this.imageFile,
    this.keypoints,
    required this.exerciseTitle,
  });

  @override
  Widget build(BuildContext context) {
    // MODIFIED: Look up the entire visualization object for the exercise.
    final exerciseVisData = _exerciseVisualizationData[exerciseTitle];
    final relevantIndices = exerciseVisData?['points'] as List<int>?;
    final connections = exerciseVisData?['connections'] as List<List<int>>?;

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
                            CustomPaint(
                              // MODIFIED: Pass both points and connections to the painter.
                              painter: KeypointPainter(
                                keypoints: keypoints!,
                                relevantKeypointIndices: relevantIndices,
                                connections: connections,
                              ),
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

/// The painter for drawing keypoints and lines on the canvas.
class KeypointPainter extends CustomPainter {
  final List<Offset> keypoints;
  final List<int>? relevantKeypointIndices;
  final List<List<int>>? connections; // NEW: Receives the connections

  KeypointPainter({
    required this.keypoints,
    this.relevantKeypointIndices,
    this.connections, // NEW: Added to constructor
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- Define paints for points and lines ---
    final linePaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 3.5;

    final pointPaint = Paint()
      ..color = Colors.redAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;
    
    // Scale all keypoints to the canvas size once
    final scaledPoints = keypoints.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

    // --- 1. Draw the connection lines ---
    if (connections != null) {
      for (final connection in connections!) {
        final startIdx = connection[0];
        final endIdx = connection[1];
        if (startIdx < scaledPoints.length && endIdx < scaledPoints.length) {
          canvas.drawLine(scaledPoints[startIdx], scaledPoints[endIdx], linePaint);
        }
      }
    }

    // --- 2. Draw the relevant keypoints on top of the lines ---
    if (relevantKeypointIndices != null) {
      for (final index in relevantKeypointIndices!) {
        if (index < scaledPoints.length) {
          canvas.drawPoints(PointMode.points, [scaledPoints[index]], pointPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant KeypointPainter oldDelegate) {
    return oldDelegate.keypoints != keypoints || 
           oldDelegate.relevantKeypointIndices != relevantKeypointIndices ||
           oldDelegate.connections != connections;
  }
}