import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import the ScoreGauge from the home screen to reuse it.
import 'therapy_home_screen.dart';

class ResultsSummaryScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> exerciseData;
  final int totalExercises;

  const ResultsSummaryScreen({
    super.key,
    required this.exerciseData,
    required this.totalExercises,
  });

  @override
  Widget build(BuildContext context) {
    // This logic correctly sums up the individual scores from the 'exerciseData' map.
    int totalScore = 0;
    exerciseData.forEach((_, data) {
      totalScore += (data['score'] as int?) ?? 0;
    });
    // This correctly calculates the maximum possible score.
    final int maxScore = totalExercises * 2;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello", style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("This is your FMA-UE score.", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade400)),
            const SizedBox(height: 32),
            Center(
              // The gauge correctly receives the total and max scores.
              child: ScoreGauge(
                score: totalScore,
                maxScore: maxScore,
                progressColor: Colors.white,
                backgroundColor: Colors.grey.shade800,
                strokeWidth: 16,
              ),
            ),
            const SizedBox(height: 48),
            Text("SUMMARY", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: exerciseData.length,
                itemBuilder: (context, index) {
                  final entry = exerciseData.entries.elementAt(index);
                  // Each summary tile correctly receives its individual score.
                  return _SummaryTile(
                    title: entry.key,
                    score: (entry.value['score'] as int?) ?? 0,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined),
                label: const Text("Download results"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A widget for each item in the summary list
// A widget for each item in the summary list
class _SummaryTile extends StatelessWidget {
  final String title;
  final int score;
  final File? startImage; // <-- ADD THIS
  final File? endImage;   // <-- ADD THIS
  final VoidCallback? onTap; // <-- ADD THIS

  const _SummaryTile({
    required this.title,
    required this.score,
    this.startImage, // <-- ADD THIS
    this.endImage,   // <-- ADD THIS
    this.onTap,      // <-- ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    // Wrap the Container with InkWell to make it tappable
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Added Expanded to prevent text overflow if the title is long
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16), // Add spacing
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(
                score.toString(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}