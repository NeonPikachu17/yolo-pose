import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

// Key for storing the user's last used model
const String _prefsKeyLastModelName = "last_used_model_name";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MaterialApp(
      title: 'Pose Vision AI',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF455A64), // Slate Blue
        scaffoldBackgroundColor: const Color(0xFFECEFF1), // Light Grey Background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF455A64), // Slate Blue Seed
          brightness: Brightness.light,
          primary: const Color(0xFF455A64),
          secondary: const Color(0xFF78909C),
          background: const Color(0xFFECEFF1),
          error: const Color(0xFFD32F2F),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(textTheme).apply(
          bodyColor: const Color(0xFF37474F),
          displayColor: const Color(0xFF263238),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFECEFF1), // Match background
          foregroundColor: const Color(0xFF263238),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: const Color(0xFF263238),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade100),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238)),
          dataRowColor: MaterialStateProperty.all(Colors.white),
          dividerThickness: 1,
        )
      ),
      home: const VisionScreen(),
    );
  }
}

// Enum to identify which image we are selecting
enum ImageRole { start, end }

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  YOLO? _yoloModel;
  
  // State variables for two-image comparison
  File? _startImageFile;
  File? _endImageFile;
  List<Map<String, dynamic>>? _startRecognitions;
  List<Map<String, dynamic>>? _endRecognitions;
  List<Map<String, String>> _comparisonResults = [];

  bool _isLoading = false;
  String? _selectedModelName;
  String? _loadingMessage;
  List<Map<String, String>> _availableModels = [];

  final List<String> _keypointNames = const [
    'Nose', 'Left Eye', 'Right Eye', 'Left Ear', 'Right Ear', 'Left Shoulder',
    'Right Shoulder', 'Left Elbow', 'Right Elbow', 'Left Wrist', 'Right Wrist',
    'Left Hip', 'Right Hip', 'Left Knee', 'Right Knee', 'Left Ankle', 'Right Ankle'
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreenData();
  }

  Future<void> _initializeScreenData() async {
      _startLoading("Discovering local models...");
      _availableModels = await _discoverLocalModels();
      final prefs = await SharedPreferences.getInstance();
      final lastModelName = prefs.getString(_prefsKeyLastModelName);

      if (lastModelName != null && _availableModels.any((m) => m['name'] == lastModelName)) {
        final modelData = _availableModels.firstWhere((m) => m['name'] == lastModelName);
        await _prepareAndLoadModel(modelData);
      } else {
          _stopLoading();
      }
    }

    Future<List<Map<String, String>>> _discoverLocalModels() async {
      final docDir = await getApplicationDocumentsDirectory();
      final files = docDir.listSync();
      final modelFiles = files.where((f) => f.path.endsWith('.tflite'));
      return modelFiles.map((modelFile) {
        final modelName = p.basenameWithoutExtension(modelFile.path);
        return {
          'name': modelName,
          'modelPath': modelFile.path,
          'labelsPath': p.join(docDir.path, "$modelName.txt"),
        };
      }).toList();
    }
  
    // ## NEW: Method to load a new model from file picker ##
    Future<void> _loadNewModelFromFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite'],
      );

      if (result == null || result.files.single.path == null) {
        _showSnackBar("No model file selected.", isError: false);
        return;
      }

      _startLoading("Copying model to app storage...");

      try {
        final pickedFile = File(result.files.single.path!);
        final docDir = await getApplicationDocumentsDirectory();
        final modelName = p.basenameWithoutExtension(pickedFile.path);
        final newModelPath = p.join(docDir.path, '$modelName.tflite');

        // Copy the selected model file to the app's documents directory
        await pickedFile.copy(newModelPath);
        
        // Also create a blank labels file, as it might be expected
        final labelsPath = p.join(docDir.path, "$modelName.txt");
        if (!await File(labelsPath).exists()) {
          await File(labelsPath).writeAsString('');
        }

        // Refresh the list of available models and load the new one
        _availableModels = await _discoverLocalModels();
        final newModelData = _availableModels.firstWhere((m) => m['name'] == modelName);

        await _prepareAndLoadModel(newModelData);

      } catch (e) {
        _showSnackBar("Error loading new model: ${e.toString()}", isError: true);
      } finally {
        _stopLoading();
      }
    }

    Future<void> _prepareAndLoadModel(Map<String, String> modelData) async {
      _startLoading("Loading ${modelData['name']}...");
      try {
        if (_yoloModel != null) await _yoloModel!.dispose();
        _yoloModel = YOLO(modelPath: modelData['modelPath']!, task: YOLOTask.pose);
        await _yoloModel?.loadModel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKeyLastModelName, modelData['name']!);
        if (mounted) {
          setState(() { _selectedModelName = modelData['name']; });
          _showSnackBar("'${modelData['name']}' loaded successfully.", isError: false);
          // When a new model is loaded, clear previous results
          _clearScreen();
        }
      } catch (e) {
        _showSnackBar("Failed to load model: ${e.toString()}", isError: true);
        if (mounted) setState(() { _yoloModel = null; _selectedModelName = null; });
      } finally {
        _stopLoading();
      }
    }

  Future<void> _pickImage(ImageRole role) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _setImage(File(image.path), role);
    }
  }

  void _setImage(File imageFile, ImageRole role) {
    setState(() {
      if (role == ImageRole.start) {
        _startImageFile = imageFile;
        _startRecognitions = null; // Reset results when image changes
      } else {
        _endImageFile = imageFile;
        _endRecognitions = null;
      }
      _comparisonResults = []; // Clear previous comparison
    });
  }

  Future<void> _runComparison() async {
    if (_startImageFile == null || _endImageFile == null || _yoloModel == null) {
      _showSnackBar("Please select both a start and an end image.", isError: true);
      return;
    }

    _startLoading("Analyzing poses...");
    try {
      // Analyze start image
      _startLoading("Analyzing Start Image...");
      final startRecs = await _analyzeImage(_startImageFile!);
      if (startRecs == null || startRecs.isEmpty) {
        throw Exception("No poses detected in the start image.");
      }

      // Analyze end image
      _startLoading("Analyzing End Image...");
      final endRecs = await _analyzeImage(_endImageFile!);
        if (endRecs == null || endRecs.isEmpty) {
        throw Exception("No poses detected in the end image.");
      }

      setState(() {
        _startRecognitions = startRecs;
        _endRecognitions = endRecs;
      });

      // Generate and display comparison results
      _generateComparisonResults();

    } catch(e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      _stopLoading();
    }
  }

  Future<List<Map<String, dynamic>>?> _analyzeImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final detections = await _yoloModel!.predict(imageBytes);

    final List<dynamic> boxes = (detections['boxes'] as List<dynamic>?) ?? [];
    final List<dynamic> allKeypoints = (detections['keypoints'] as List<dynamic>?) ?? [];
    
    if (boxes.isEmpty) return null;

    final formattedRecognitions = <Map<String, dynamic>>[];
    for (int i = 0; i < boxes.length; i++) {
        final List<Map<String, double>>? parsedKeypoints = _parseKeypointsForIndex(allKeypoints, i);
        
        Map<String, double>? armScores;
        if (parsedKeypoints != null) {
          armScores = _scoreArmRaise(parsedKeypoints);
        }
        
        formattedRecognitions.add({
          'keypoints': parsedKeypoints,
          'armScores': armScores,
        });
    }
    return formattedRecognitions;
  }
  
  void _generateComparisonResults() {
    if (_startRecognitions == null || _endRecognitions == null) return;
    
    // For simplicity, we compare the first detected person in each image
    final startPose = _startRecognitions![0];
    final endPose = _endRecognitions![0];

    final startKeypoints = startPose['keypoints'] as List<Map<String, double>>?;
    final endKeypoints = endPose['keypoints'] as List<Map<String, double>>?;
    final endScores = endPose['armScores'] as Map<String, double>? ?? {'left': 0.0, 'right': 0.0};
    
    if(startKeypoints == null || endKeypoints == null) return;

    final double leftStartAngle = _calculateAngle(startKeypoints[11], startKeypoints[5], startKeypoints[7]);
    final double leftEndAngle = _calculateAngle(endKeypoints[11], endKeypoints[5], endKeypoints[7]);
    final double rightStartAngle = _calculateAngle(startKeypoints[12], startKeypoints[6], startKeypoints[8]);
    final double rightEndAngle = _calculateAngle(endKeypoints[12], endKeypoints[6], endKeypoints[8]);

    final results = [
      {
        'Metric': 'Left Arm Raise',
        'Start Position': '${leftStartAngle.toStringAsFixed(1)}°',
        'End Position': '${leftEndAngle.toStringAsFixed(1)}°',
        'Score': '${endScores['left']} pts',
      },
      {
        'Metric': 'Right Arm Raise',
        'Start Position': '${rightStartAngle.toStringAsFixed(1)}°',
        'End Position': '${rightEndAngle.toStringAsFixed(1)}°',
        'Score': '${endScores['right']} pts',
      }
    ];

    setState(() {
      _comparisonResults = results;
    });
  }

  double _calculateAngle(Map<String, double> p1, Map<String, double> p2, Map<String, double> p3) {
    if (p1['confidence']! < 0.3 || p2['confidence']! < 0.3 || p3['confidence']! < 0.3) return 0.0;
    final vec1x = p1['x']! - p2['x']!;
    final vec1y = p1['y']! - p2['y']!;
    final vec2x = p3['x']! - p2['x']!;
    final vec2y = p3['y']! - p2['y']!;
    final dotProduct = vec1x * vec2x + vec1y * vec2y;
    final mag1 = math.sqrt(vec1x * vec1x + vec1y * vec1y);
    final mag2 = math.sqrt(vec2x * vec2x + vec2y * vec2y);
    if (mag1 * mag2 == 0) return 0.0;
    final cosAngle = dotProduct / (mag1 * mag2);
    final angle = math.acos(math.max(-1.0, math.min(1.0, cosAngle)));
    return angle * (180 / math.pi);
  }

  Map<String, double> _scoreArmRaise(List<Map<String, double>> keypoints) {
    double leftArmScore = 0.0;
    double rightArmScore = 0.0;

    final leftAngle = _calculateAngle(keypoints[11], keypoints[5], keypoints[7]); // LHip, LShoulder, LElbow
    if (leftAngle > 160) { leftArmScore = 2.0; } 
    else if (leftAngle > 70 && leftAngle < 110) { leftArmScore = 0.5; }

    final rightAngle = _calculateAngle(keypoints[12], keypoints[6], keypoints[8]); // RHip, RShoulder, RElbow
    if (rightAngle > 160) { rightArmScore = 2.0; }
    else if (rightAngle > 70 && rightAngle < 110) { rightArmScore = 0.5; }

    return {'left': leftArmScore, 'right': rightArmScore};
  }

  List<Map<String, double>>? _parseKeypointsForIndex(List<dynamic> allKeypoints, int index) {
    if (index < 0 || index >= allKeypoints.length) return null;

    final personData = allKeypoints[index];
    final coordinates = personData['coordinates'] as List<dynamic>?;
    if (coordinates == null) return null;

    final List<Map<String, double>> parsedKeypoints = [];
    for (var pointData in coordinates) {
      if (pointData is Map && pointData.containsKey('x') && pointData.containsKey('y') && pointData.containsKey('confidence')) {
        final x = (pointData['x'] as num).toDouble();
        final y = (pointData['y'] as num).toDouble();
        final confidence = (pointData['confidence'] as num).toDouble();
        parsedKeypoints.add({'x': x, 'y': y, 'confidence': confidence});
      }
    }
    return parsedKeypoints.isNotEmpty ? parsedKeypoints : null;
  }
  
  void _clearScreen() => setState(() {
    _startImageFile = null;
    _endImageFile = null;
    _startRecognitions = null;
    _endRecognitions = null;
    _comparisonResults = [];
  });

  void _startLoading(String message) => setState(() { _isLoading = true; _loadingMessage = message; });
  void _stopLoading() => setState(() { _isLoading = false; _loadingMessage = null; });
  
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _yoloModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ## MODIFIED: Added AppBar with actions ##
      appBar: AppBar(
        title: const Text("Pose Comparison"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Load New Model",
            onPressed: _loadNewModelFromFile,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all_rounded),
            tooltip: "Clear Selections",
            onPressed: (_startImageFile != null || _endImageFile != null) ? _clearScreen : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_loadingMessage ?? "Loading...", style: Theme.of(context).textTheme.bodyLarge),
            ]))
          : LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Wide screen layout for tablets and desktops
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildImageSelectionPanel()),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 4, child: _buildResultsPanel()),
                  ],
                );
              } else {
                // Narrow screen layout for phones
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildImageSelectionPanel(),
                      const Divider(),
                      _buildResultsPanel(),
                    ],
                  ),
                );
              }
            }),
    );
  }

  Widget _buildImageSelectionPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageSelectionCard(
            title: "Start Position",
            imageFile: _startImageFile,
            onTap: () => _pickImage(ImageRole.start),
          ),
          const SizedBox(height: 24),
          _buildImageSelectionCard(
            title: "End Position",
            imageFile: _endImageFile,
            onTap: () => _pickImage(ImageRole.end),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text("Compare Poses"),
            onPressed: (_startImageFile != null && _endImageFile != null && _yoloModel != null) ? _runComparison : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildImageSelectionCard({required String title, File? imageFile, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 250,
              width: double.infinity,
              color: Colors.blueGrey.shade50,
              child: imageFile != null
                  ? Image.file(imageFile, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.blueGrey)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ## MODIFIED: Added row with title and model selector ##
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Comparison Results", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Expanded(flex: 2, child: _buildModelSelector()),
            ],
          ),
          const SizedBox(height: 16),
          _comparisonResults.isEmpty
              ? const Card(child: SizedBox(height: 150, child: Center(child: Text("Run comparison to see results"))))
              : _buildResultsTable(),
        ],
      ),
    );
  }
  
  // ## NEW: Widget for selecting the active model ##
  Widget _buildModelSelector() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelText: "Model",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      value: _selectedModelName,
      hint: const Text("No Model", overflow: TextOverflow.ellipsis),
      onChanged: (String? newValue) {
        if (newValue != null) {
          final modelData = _availableModels.firstWhere((m) => m['name'] == newValue);
          _prepareAndLoadModel(modelData);
        }
      },
      items: _availableModels.map<DropdownMenuItem<String>>((model) {
        return DropdownMenuItem<String>(
          value: model['name'],
          child: Text(
            model['name']!, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultsTable() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Metric')),
          DataColumn(label: Text('Start'), numeric: true),
          DataColumn(label: Text('End'), numeric: true),
          DataColumn(label: Text('Score'), numeric: true),
        ],
        rows: _comparisonResults.map((result) {
          return DataRow(cells: [
            DataCell(Text(result['Metric'] ?? '')),
            DataCell(Text(result['Start Position'] ?? '')),
            DataCell(Text(result['End Position'] ?? '')),
            DataCell(Text(result['Score'] ?? '')),
          ]);
        }).toList(),
      ),
    );
  }
}