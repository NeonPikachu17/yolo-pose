import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:path/path.dart' as p;

import 'body_side.dart'; // Import the new enum
import 'results_summary_screen.dart';
import 'exercise_upload_sheet.dart';
import 'submitted_photos_screen.dart';

// --- DATA MODELS ---
class Exercise {
  final String title;
  final String subtitle;
  final String instructions;
  // MODIFIED: Scoring function now accepts a BodySide
  final Function(List<Map<String, double>>, List<Map<String, double>>, BodySide) scoringFunction;

  Exercise({
    required this.title,
    required this.subtitle,
    required this.instructions,
    required this.scoringFunction,
  });
}

// --- HOME SCREEN WIDGET ---
class TherapyHomeScreen extends StatefulWidget {
  const TherapyHomeScreen({super.key});

  @override
  State<TherapyHomeScreen> createState() => _TherapyHomeScreenState();
}

class _TherapyHomeScreenState extends State<TherapyHomeScreen> {
  YOLO? _yoloModel;
  bool _isLoading = false;
  String? _loadingMessage;
  String? _selectedModelName;
  final Map<String, Map<String, dynamic>> _exerciseData = {};
  late final List<Exercise> exercises;

  @override
  void initState() {
    super.initState();
    exercises = [
      Exercise(
        title: "Shoulder Abduction",
        subtitle: "Arm out to shoulder",
        instructions: "Raise your arm out to your side. Keep your arm straight.",
        scoringFunction: _scoreShoulderAbduction,
      ),
      Exercise(
        title: "Hand to Lumbar Spine",
        subtitle: "Hand behind back",
        instructions: "Reach your hand behind your back to touch your lower spine.",
        scoringFunction: _scoreHandtoLumbarSpine,
      ),
      Exercise(
        title: "Shoulder Flexion 0-90",
        subtitle: "Hand behind back",
        instructions: "Reach your hand behind your back to touch your lower spine.",
        scoringFunction: (start, end, side) => {'score': 0, 'details': 'Scoring not implemented.'},
      ),
      Exercise(
        title: "Shoulder Flexion 90-180",
        subtitle: "Hand behind back",
        instructions: "Reach your hand behind your back to touch your lower spine.",
        scoringFunction: (start, end, side) => {'score': 0, 'details': 'Scoring not implemented.'},
      ),
    ];
    _loadModelFromAssets();
  }
  
  // --- SCORING FUNCTIONS ---
  Map<String, dynamic> _scoreShoulderAbduction(List<Map<String, double>> startKeypoints, List<Map<String, double>> endKeypoints, BodySide side) {
    // COCO Keypoint indices:
    // Left side: LHip=11, LShoulder=5, LElbow=7
    // Right side: RHip=12, RShoulder=6, RElbow=8
    
    // FIX: Corrected the indices for the right side.
    final hipIndex = side == BodySide.left ? 11 : 12;
    final shoulderIndex = side == BodySide.left ? 5 : 6; // Was 7 for right side, now corrected to 6
    final elbowIndex = side == BodySide.left ? 7 : 8;

    final endAngle = _calculateAngle(endKeypoints[hipIndex], endKeypoints[shoulderIndex], endKeypoints[elbowIndex]);
    int score;
    
    if (endAngle >= 85) {
      score = 2; // Full range of motion
    } else if (endAngle >= 20) {
      score = 1; // Partial range of motion
    } else {
      score = 0; // Limited range of motion
    }

    return {
      'score': score,
      'details': 'Target: 90.0°, Achieved: ${endAngle.toStringAsFixed(1)}° (${side.name} side)'
    };
  }

  // --- SCORING FUNCTIONS ---
  // NEW AND IMPROVED SCORING LOGIC
  Map<String, dynamic> _scoreHandtoLumbarSpine(List<Map<String, double>> startKeypoints, List<Map<String, double>> endKeypoints, BodySide side) {
    final shoulderIndex = side == BodySide.left ? 5 : 6;
    final elbowIndex = side == BodySide.left ? 7 : 8;
    final wristIndex = side == BodySide.left ? 9 : 10;
    
    // Calculate the starting angle as a baseline.
    final startAngle = _calculateAngle(startKeypoints[shoulderIndex], startKeypoints[elbowIndex], startKeypoints[wristIndex]);
    
    // Calculate the final angle.
    final endAngle = _calculateAngle(endKeypoints[shoulderIndex], endKeypoints[elbowIndex], endKeypoints[wristIndex]);
    
    // Determine the change in angle, which is the measure of movement.
    final angleChange = (startAngle - endAngle).abs();
    
    int score;
    String details;
    
    // Scoring based on a realistic change in angle.
    // The smaller the end angle, the better the score.
    if (endAngle <= 60) {
      score = 2; // Excellent range of motion, hand is close to the lumbar spine
      details = 'Achieved: ${endAngle.toStringAsFixed(1)}°. Excellent range of motion!';
    } else if (endAngle <= 90) {
      score = 1; // Good range of motion
      details = 'Achieved: ${endAngle.toStringAsFixed(1)}°. Good range of motion.';
    } else {
      score = 0; // Limited range of motion
      details = 'Achieved: ${endAngle.toStringAsFixed(1)}°. Limited range of motion.';
    }

    return {
      'score': score,
      'details': 'Target: <= 60.0°, Achieved: ${endAngle.toStringAsFixed(1)}° (${side.name} side) - ' + details,
    };
  }

  // --- MODEL LOADING & MANAGEMENT ---
  Future<void> _loadModelFromAssets() async {
    _startLoading("Loading built-in model...");
    try {
      const modelAssetPath = 'assets/models/yolo11m-pose_float32.tflite'; // Your model
      final modelName = p.basenameWithoutExtension(modelAssetPath);
      final directory = await getApplicationDocumentsDirectory();
      final modelPath = p.join(directory.path, p.basename(modelAssetPath));
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        final byteData = await rootBundle.load(modelAssetPath);
        await modelFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
      final modelData = {'name': modelName, 'modelPath': modelPath};
      await _prepareAndLoadModel(modelData);
    } catch (e) {
      _showSnackBar("Error loading built-in model: ${e.toString()}", isError: true);
      if (mounted) setState(() { _yoloModel = null; _selectedModelName = null; });
    } finally {
      _stopLoading();
    }
  }

  Future<void> _prepareAndLoadModel(Map<String, String> modelData) async {
    try {
      await _yoloModel?.dispose();
      // FIX: Changed modelData['path'] to modelData['modelPath']
      _yoloModel = YOLO(modelPath: modelData['modelPath']!, task: YOLOTask.pose);
      await _yoloModel?.loadModel();
      if (mounted) {
        setState(() => _selectedModelName = modelData['name']);
        _showSnackBar("'${modelData['name']}' loaded successfully.", isError: false);
      }
    } catch (e) {
      _showSnackBar("Failed to load model: ${e.toString()}", isError: true);
      if (mounted) {
        setState(() {
        _yoloModel = null;
        _selectedModelName = null;
      });
      }
    }
  }

  // --- CORE ANALYSIS LOGIC ---
  Future<void> _analyzeAndScoreExercise(Exercise exercise, File startImage, File endImage) async {
    if (_yoloModel == null) {
      _showSnackBar("Model is not loaded. Please restart the app.", isError: true);
      return;
    }
    
    // MODIFIED: Retrieve the selected side for the analysis
    final selectedSide = _exerciseData[exercise.title]?['side'] as BodySide?;
    if (selectedSide == null) {
      _showSnackBar("Could not determine body side. Please re-select.", isError: true);
      return;
    }

    _startLoading("Analyzing poses...");
    try {
      final startKeypoints = await _runInference(startImage);
      final endKeypoints = await _runInference(endImage);

      if (startKeypoints == null || endKeypoints == null) {
        throw Exception("Could not detect a person in one or both images.");
      }
      
      // MODIFIED: Pass the selected side to the scoring function
      final results = exercise.scoringFunction(startKeypoints, endKeypoints, selectedSide);

      setState(() {
        final exerciseEntry = _exerciseData.putIfAbsent(exercise.title, () => {});
        exerciseEntry['score'] = results['score'];
        exerciseEntry['results'] = results['details'];
        exerciseEntry['start_keypoints'] = _convertKeypointsToData(startKeypoints);
        exerciseEntry['end_keypoints'] = _convertKeypointsToData(endKeypoints);
        exerciseEntry['side'] = selectedSide; // Ensure side is saved
      });
      _showSnackBar("${exercise.title} scored successfully!", isError: false);

    } catch (e) {
      _showSnackBar("Analysis Error: ${e.toString()}", isError: true);
    } finally {
      _stopLoading();
    }
  }
  
  Future<List<Map<String, double>>?> _runInference(File imageFile) async {
    // Read the image and run inference
    final imageBytes = await imageFile.readAsBytes();
    final detections = await _yoloModel!.predict(imageBytes);

    print("Full results structure: $detections");
    print("Results keys: ${detections.keys}");
    // Debug: Print the raw detections
    print('DEBUG: Raw YOLO detections: $detections');

    final allKeypoints = (detections['keypoints'] as List<dynamic>?) ?? [];
    if (allKeypoints.isEmpty) {
      print('DEBUG: No keypoints detected.');
      return null;
    }

    // Get the keypoints for the first detected person
    final personData = allKeypoints[0];
    final coordinates = personData['coordinates'] as List<dynamic>?;
    if (coordinates == null) {
      print('DEBUG: Keypoint coordinates are null.');
      return null;
    }

    final List<Map<String, double>> parsedKeypoints = [];
    for (var i = 0; i < coordinates.length; i++) {
      var pointData = coordinates[i];
      parsedKeypoints.add({
        'x': (pointData['x'] as num).toDouble(),
        'y': (pointData['y'] as num).toDouble(),
        'confidence': (pointData['confidence'] as num).toDouble(),
      });
    }

    // Debug: Print the number of parsed keypoints
    print('DEBUG: Parsed ${parsedKeypoints.length} keypoints.');
    
    // Debug: Print the values of each parsed keypoint
    for (var i = 0; i < parsedKeypoints.length; i++) {
      final point = parsedKeypoints[i];
      print('DEBUG: Keypoint $i (x: ${point['x']!.toStringAsFixed(2)}, y: ${point['y']!.toStringAsFixed(2)}, confidence: ${point['confidence']!.toStringAsFixed(2)})');
    }

    // Check if all 17 keypoints were detected
    return parsedKeypoints.length == 17 ? parsedKeypoints : null;
  }

  double _calculateAngle(Map<String, double> p1, Map<String, double> p2, Map<String, double> p3) {
    // ... (This function is unchanged)
    if (p1['confidence']! < 0.3 || p2['confidence']! < 0.3 || p3['confidence']! < 0.3) return 0.0;
    double angle = (math.atan2(p3['y']! - p2['y']!, p3['x']! - p2['x']!) - math.atan2(p1['y']! - p2['y']!, p1['x']! - p2['x']!)) * 180 / math.pi;
    angle = angle.abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }
  
  // MODIFIED: Now also accepts and stores the selected body side
  void _onImageUploaded(String exerciseTitle, String imageType, File imageFile, BodySide side) {
    setState(() {
      final entry = _exerciseData.putIfAbsent(exerciseTitle, () => {});
      entry[imageType] = imageFile;
      entry['side'] = side;
    });
    print('DEBUG: Saved side for $exerciseTitle is ${side.name}');
  }

  int get _currentScore {
    int score = 0;
    _exerciseData.forEach((_, data) {
      score += data.values.whereType<File>().length;
    });
    return score;
  }

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

  // --- UI BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    final int currentScore = _currentScore;
    final int maxScore = exercises.length * 2;
    final bool allExercisesCompleted = exercises.every((ex) => (_exerciseData[ex.title]?['score'] as int?) != null);

    return Scaffold(
      backgroundColor: Colors.white,
      // MODIFIED: The AppBar is now cleaner, with no manual load button.
      appBar: AppBar(
        // The status display remains to give feedback on the loaded model.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _selectedModelName != null ? 'Model: $_selectedModelName' : 'Loading Model...',
              style: GoogleFonts.poppins(
                color: _selectedModelName != null ? Colors.green.shade800 : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: allExercisesCompleted
        ? _buildSubmitButton(context)
        : null,
      body: _isLoading
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_loadingMessage ?? "Loading...", style: Theme.of(context).textTheme.bodyLarge),
          ]))
        : ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildScoreCard(currentScore, maxScore),
              const SizedBox(height: 40),
              ...exercises.map((exercise) {
                final data = _exerciseData[exercise.title];
                final isCompleted = (data?['score'] as int?) != null;
                
                return _ExerciseTile(
                  title: exercise.title,
                  subtitle: exercise.subtitle,
                  isCompleted: isCompleted,
                  onTap: () async {
                    final bool? shouldAnalyze = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ExerciseUploadSheet(
                        exercise: exercise,
                        onImageUploaded: _onImageUploaded,
                      ),
                    );

                    if (shouldAnalyze == true) {
                      final startImg = _exerciseData[exercise.title]?['start'] as File?;
                      final endImg = _exerciseData[exercise.title]?['end'] as File?;

                      if (startImg != null && endImg != null) {
                        await _analyzeAndScoreExercise(exercise, startImg, endImg);
                      }
                    }
                  },
                );
              }),
            ],
          ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    // ... (This widget's code is unchanged)
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsSummaryScreen(
                exerciseData: _exerciseData,
                totalExercises: exercises.length,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(
          "Submit",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildScoreCard(int currentScore, int maxScore) {
    // ... (This widget's code is unchanged)
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Completion Progress", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _exerciseData.isNotEmpty
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubmittedPhotosScreen(exerciseData: _exerciseData)))
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade400, foregroundColor: Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  child: Text("View Results", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Spacer(),
            ScoreGauge(score: currentScore, maxScore: maxScore),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _startLoading(String message) => setState(() { _isLoading = true; _loadingMessage = message; });
  void _stopLoading() => setState(() { _isLoading = false; _loadingMessage = null; });
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade700,
    ));
  }
}

/// A reusable tile for displaying an exercise.
class _ExerciseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted; // NEW: To know its current state
  final VoidCallback onTap; // NEW: To handle taps

  const _ExerciseTile({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // NEW: Use green as an accent color for completed items
    final Color accentColor = isCompleted ? Colors.green.shade600 : Colors.black;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      // CHANGED: Style the card differently if it's completed
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCompleted ? accentColor : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      color: isCompleted ? Colors.green.withOpacity(0.05) : Colors.white,
      // NEW: Wrap with InkWell to make it tappable
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isCompleted ? accentColor.withOpacity(0.2) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // CHANGED: Show a checkmark icon if completed, otherwise show an arrow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? accentColor.withOpacity(0.5) : Colors.grey.shade300,
                    width: 1.5
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.transparent,
                  foregroundColor: accentColor,
                  child: Icon(
                    isCompleted ? Icons.check : Icons.arrow_forward,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A widget that stacks the CustomPainter and the score text. (Unchanged)
class ScoreGauge extends StatelessWidget {
  final int score;
  final int maxScore;
  // NEW: Added optional parameters to allow for different styling.
  final Color? progressColor;
  final Color? backgroundColor;
  final double? strokeWidth;

  const ScoreGauge({
    super.key,
    required this.score,
    required this.maxScore,
    // Initialize the new optional parameters in the constructor.
    this.progressColor,
    this.backgroundColor,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Use provided colors/styles or fall back to default values.
    final pColor = progressColor ?? Colors.black;
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
                    color: pColor, // Use the progress color for the score text
                  ),
                ),
                TextSpan(
                  text: '/$maxScore',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: bgColor.withOpacity(0.9), // Use the background color for the max score text
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

/// This CustomPainter is the "brain" of the gauge. It handles all the drawing. (Unchanged)
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

    // FIX: Ensure progress is never greater than 1.0 to avoid overdrawing
    final progress = (score / maxScore).clamp(0.0, 1.0);
    final progressSweepAngle = progress * sweepAngle;
    canvas.drawArc(rect, startAngle, progressSweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; 
  }
}

  // New data class to hold keypoint and confidence
class KeypointData {
  final Offset offset;
  final double confidence;
  KeypointData(this.offset, this.confidence);
}