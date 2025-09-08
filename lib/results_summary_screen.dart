import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'submitted_photos_screen.dart'; // We'll now navigate to this screen.

// --- WIDGETS ---
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
    int totalScore = 0;
    exerciseData.forEach((_, data) {
      totalScore += (data['score'] as int?) ?? 0;
    });
    final int maxScore = totalExercises * 2;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello", style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black)),
            Text("This is your FMA-UE score.", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700)),
            const SizedBox(height: 32),
            Center(
              child: ScoreGauge(
                score: totalScore,
                maxScore: maxScore,
                progressColor: Colors.blue.shade700,
                backgroundColor: Colors.blue.shade200,
                strokeWidth: 16,
              ),
            ),
            const SizedBox(height: 48),
            Text("SUMMARY", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: exerciseData.length,
                itemBuilder: (context, index) {
                  final entry = exerciseData.entries.elementAt(index);
                  return _SummaryTile(
                    title: entry.key,
                    score: (entry.value['score'] as int?) ?? 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubmittedPhotosScreen(
                            exerciseData: {entry.key: entry.value},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final int score;
  final VoidCallback? onTap;

  const _SummaryTile({
    required this.title,
    required this.score,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade700,
              child: Text(
                score.toString(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreGauge extends StatelessWidget {
  final int score;
  final int maxScore;
  final Color? progressColor;
  final Color? backgroundColor;
  final double? strokeWidth;

  const ScoreGauge({
    super.key,
    required this.score,
    required this.maxScore,
    this.progressColor,
    this.backgroundColor,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = progressColor ?? Colors.green.shade700;
    final bgColor = backgroundColor ?? Colors.grey.shade300;

    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(100),
            painter: ScoreGaugePainter(
              score: score,
              maxScore: maxScore,
              progressColor: pColor,
              backgroundColor: bgColor,
              strokeWidth: strokeWidth ?? 12,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$score',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: pColor,
                  ),
                ),
                TextSpan(
                  text: '/$maxScore',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: bgColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ScoreGaugePainter extends CustomPainter {
  final int score;
  final int maxScore;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  ScoreGaugePainter({
    required this.score,
    required this.maxScore,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -2.35;
    const sweepAngle = 4.7;

    canvas.drawArc(rect, startAngle, sweepAngle, false, backgroundPaint);

    final progress = (score / maxScore).clamp(0.0, 1.0);
    final progressSweepAngle = progress * sweepAngle;
    canvas.drawArc(rect, startAngle, progressSweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}