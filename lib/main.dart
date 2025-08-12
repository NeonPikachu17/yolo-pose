import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
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
      ),
      home: const VisionScreen(),
    );
  }
}

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  YOLO? _yoloModel;
  File? _imageFile;
  List<Map<String, dynamic>> _recognitions = [];
  bool _isLoading = false;
  String? _selectedModelName;
  String? _loadingMessage;
  double _originalImageHeight = 0;
  double _originalImageWidth = 0;

  int? _selectedDetectionIndex;
  Map<String, Color> _classColorMap = {};
  List<Map<String, String>> _availableModels = [];

  double _keypointConfidenceThreshold = 0.5;

  final List<Color> _boxColors = [
    Colors.deepOrange, Colors.lightBlue, Colors.amber.shade600, Colors.pink,
    Colors.green, Colors.purple, Colors.red, Colors.teal,
    Colors.indigo, Colors.cyan, Colors.brown, Colors.lime.shade800,
  ];

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

    if (lastModelName != null &&
        _availableModels.any((m) => m['name'] == lastModelName)) {
      final modelData =
          _availableModels.firstWhere((m) => m['name'] == lastModelName);
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

  Future<void> _importModelFromPicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final file = result.files.single;

    if (file.extension?.toLowerCase() != 'tflite') {
      _showSnackBar("Invalid file type. Please select a .tflite model.",
          isError: true);
      return;
    }

    _startLoading("Importing model...");
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final newModelPath = p.join(docDir.path, file.name);

      if (await File(newModelPath).exists()) {
        _showSnackBar("A model with this name already exists.", isError: true);
        _stopLoading();
        return;
      }

      await File(file.path!).copy(newModelPath);
      final newLabelsPath =
          p.join(docDir.path, "${p.basenameWithoutExtension(file.name)}.txt");
      if (!await File(newLabelsPath).exists()) {
        await File(newLabelsPath).create();
      }

      _showSnackBar("'${file.name}' imported successfully!", isError: false);
      await _handleRefresh();
    } catch (e) {
      _showSnackBar("Error importing model: $e", isError: true);
      _stopLoading();
    }
  }

  Future<void> _prepareAndLoadModel(Map<String, String> modelData) async {
    _clearScreen();
    _startLoading("Loading ${modelData['name']}...");

    try {
      final targetModelPath = modelData['modelPath']!;
      if (!await File(targetModelPath).exists()) {
        throw Exception("Model file not found. It may have been deleted.");
      }

      if (_yoloModel != null) await _yoloModel!.dispose();

      _yoloModel = YOLO(modelPath: targetModelPath, task: YOLOTask.pose);
      await _yoloModel?.loadModel();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyLastModelName, modelData['name']!);

      if (mounted) {
        setState(() {
          _selectedModelName = modelData['name'];
        });
        _showSnackBar("'${modelData['name']}' loaded successfully.",
            isError: false);
      }
    } catch (e) {
      _showSnackBar("Failed to load model: ${e.toString()}", isError: true);
      if (mounted) {
        setState(() {
          _yoloModel = null;
          _selectedModelName = null;
        });
      }
    } finally {
      _stopLoading();
    }
  }

  Future<void> _deleteLocallyStoredModel(String modelName) async {
    final modelData =
        _availableModels.firstWhere((m) => m['name'] == modelName);
    final modelFile = File(modelData['modelPath']!);
    final labelsFile = File(modelData['labelsPath']!);

    if (await modelFile.exists()) await modelFile.delete();
    if (await labelsFile.exists()) await labelsFile.delete();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefsKeyLastModelName) == modelName) {
      await prefs.remove(_prefsKeyLastModelName);
    }

    if (_selectedModelName == modelName) {
      _clearScreen();
      setState(() {
        _yoloModel = null;
        _selectedModelName = null;
      });
    }

    await _handleRefresh();
    _showSnackBar("Deleted '$modelName'.", isError: false);
  }

  Future<void> _processImage(XFile image) async {
    final imageBytes = await image.readAsBytes();
    final decodedImage = await decodeImageFromList(imageBytes);

    setState(() {
      _imageFile = File(image.path);
      _recognitions = [];
      _originalImageWidth = decodedImage.width.toDouble();
      _originalImageHeight = decodedImage.height.toDouble();
      _selectedDetectionIndex = null;
    });

    if (_yoloModel != null) {
      _runInference();
    } else {
      _showSnackBar("Please select and load a model first.", isError: true);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) await _processImage(image);
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) await _processImage(image);
  }

  List<Map<String, double>>? _parseKeypointsForIndex(List<dynamic> allKeypoints, int index) {
    // 1. Check if the index is valid for the keypoints list.
    if (index < 0 || index >= allKeypoints.length) {
      return null;
    }

    // 2. Remove the incorrect loop and access the person's data directly by index.
    final box = allKeypoints[index];
    final coordinates = box['coordinates'];

    // ## MODIFIED: THIS IS THE NEW PARSING LOGIC ##
    List<Map<String, double>>? parsedKeypoints;
    if (coordinates != null) {
      final keypointsForPerson = coordinates as List<dynamic>;
      parsedKeypoints = [];

      for (var pointData in keypointsForPerson) {
        if (pointData != null && pointData.isNotEmpty) {
          final x = pointData['x'] as double?;
          final y = pointData['y'] as double?;
          final confidence = pointData['confidence'] as double?;

          if (x != null && y != null && confidence != null) {
            parsedKeypoints.add({
              'x': x,
              'y': y,
              'confidence': confidence,
            });
          }
        }
      }
      // Check if the index is valid for the keypoints list
      if (index < 0 || index >= allKeypoints.length) {
        return null;
      }
    }
    return parsedKeypoints;
  }

  Future<void> _runInference() async {
    if (_imageFile == null || _yoloModel == null) return;
    _startLoading("Estimating poses...");

    try {
      final imageBytes = await _imageFile!.readAsBytes();
      final detections = await _yoloModel!.predict(imageBytes);


      if (!mounted) return;

      final double modelImageWidth =
          (detections['image_width'] as num?)?.toDouble() ??
              _originalImageWidth;
      final double modelImageHeight =
          (detections['image_height'] as num?)?.toDouble() ??
              _originalImageHeight;

      final formattedRecognitions = <Map<String, dynamic>>[];
      final tempColorMap = <String, Color>{};
      int colorIndex = 0;
      final List<dynamic> boxes = (detections['boxes'] as List<dynamic>?) ?? [];
      final List<dynamic> allKeypoints = (detections['keypoints'] as List<dynamic>?) ?? [];

      // 2. Loop through each detected box using its index
      for (int i = 0; i < boxes.length; i++) {
        final box = boxes[i];
        final className = box['className'] as String; // Get the correct class name

        // 3. Call the new helper function to parse keypoints for the current index
        final List<Map<String, double>>? parsedKeypoints = _parseKeypointsForIndex(allKeypoints, i);

        formattedRecognitions.add({
          'x1': box['x1'],
          'y1': box['y1'],
          'x2': box['x2'],
          'y2': box['y2'],
          'className': className, // Use the correct string class name
          'confidence': box['confidence'],
          'keypoints': parsedKeypoints, // Add the parsed keypoints
        });

        if (!tempColorMap.containsKey(className)) {
          tempColorMap[className] = _boxColors[colorIndex % _boxColors.length];
          colorIndex++;
        }
      }

      setState(() {
        _recognitions = formattedRecognitions;
        _classColorMap = tempColorMap;
        _originalImageWidth = modelImageWidth;
        _originalImageHeight = modelImageHeight;
      });
    } catch (e) {
      _showSnackBar("Error during analysis: $e", isError: true);
    } finally {
      _stopLoading();
    }
  }

  Future<void> _handleRefresh() async {
    _clearScreen();
    await _initializeScreenData();
  }

  void _startLoading(String message) =>
      setState(() {
        _isLoading = true;
        _loadingMessage = message;
      });
  void _stopLoading() => setState(() {
        _isLoading = false;
        _loadingMessage = null;
      });
  void _clearScreen() => setState(() {
        _imageFile = null;
        _recognitions = [];
        _selectedDetectionIndex = null;
      });

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _yoloModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pose Vision AI")),
      bottomNavigationBar: _buildBottomActionBar(),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _buildModelManagementCard(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildContentArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelManagementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("POSE ESTIMATION",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedModelName ?? "No Model Selected",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _yoloModel != null
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _showModelSelectionSheet,
                  child: const Text("Change Model"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showModelSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Available Models",
                  style: Theme.of(context).textTheme.headlineSmall),
              const Divider(height: 24),
              if (_availableModels.isEmpty)
                const Expanded(
                    child: Center(child: Text("No local models found.")))
              else
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _availableModels.length,
                    itemBuilder: (context, index) {
                      final model = _availableModels[index];
                      return ListTile(
                        title: Text(model['name']!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        selected: _selectedModelName == model['name'],
                        selectedTileColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _prepareAndLoadModel(model);
                        },
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showDeleteConfirmationDialog(model['name']!);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text("Import New Model"),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _importModelFromPicker();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final bool isReadyForAnalysis = _yoloModel != null && !_isLoading;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text("Gallery"),
                onPressed: isReadyForAnalysis ? _pickImage : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text("Camera"),
                onPressed: isReadyForAnalysis ? _takePicture : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    if (_isLoading) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.symmetric(vertical: 50.0),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const CircularProgressIndicator(),
            if (_loadingMessage != null) ...[
              const SizedBox(height: 20),
              Text(_loadingMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
            ]
          ]),
        ),
      );
    }
    if (_imageFile != null) {
      return _buildDetectionView();
    }
    return Container(
      key: const ValueKey('initial'),
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.accessibility_new_rounded,
              size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
              _yoloModel == null
                  ? "Select a Model"
                  : "Ready for Pose Estimation",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            _yoloModel == null
                ? "Choose a model to begin."
                : "Use the action bar below to select an image.",
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ]),
      ),
    );
  }

  Widget _buildDetectionView() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 700) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: _buildResultsImage()),
          const SizedBox(width: 20),
          Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildControlsCard(),
                  const SizedBox(height: 16),
                  _buildResultsList(),
                ],
              )),
        ]);
      } else {
        return Column(children: [
          _buildResultsImage(),
          const SizedBox(height: 20),
          _buildControlsCard(),
          const SizedBox(height: 16),
          _buildResultsList(),
        ]);
      }
    });
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Debugging Tools",
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            Text(
                "Keypoint Confidence: ${(_keypointConfidenceThreshold * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _keypointConfidenceThreshold,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label:
                  "${(_keypointConfidenceThreshold * 100).toStringAsFixed(0)}%",
              onChanged: (value) {
                setState(() {
                  _keypointConfidenceThreshold = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsImage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Analysis Result",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: _clearScreen,
                icon: const Icon(Icons.close_rounded),
                tooltip: "Clear Image"),
          ],
        ),
        const SizedBox(height: 12),
        Card(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: _recognitions.isEmpty && !_isLoading
                ? _buildNoDetectionsFound()
                : _buildImageWithDetections())
      ]);

  Widget _buildResultsList() => Column(children: [
        Text("Detected Poses: ${_recognitions.length}",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildDetectionList(),
      ]);

  Widget _buildNoDetectionsFound() =>
      Stack(alignment: Alignment.center, children: [
        if (_imageFile != null) Image.file(_imageFile!),
        Container(
            color: Colors.black.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Text("No poses detected",
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)))
      ]);

  Widget _buildImageWithDetections() {
    if (_imageFile == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      if (_originalImageWidth == 0) return const SizedBox.shrink();

      // The scaleRatio is only needed here to calculate the canvas height
      final scaleRatio = constraints.maxWidth / _originalImageWidth;

      return FutureBuilder<ui.Image>(
          future: _loadImage(_imageFile!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return CustomPaint(
                size: Size(
                    constraints.maxWidth, _originalImageHeight * scaleRatio),
                // ## FIX: Removed scaleRatio from the painter ##
                painter: _DetectionPainter(
                  originalImage: snapshot.data!,
                  recognitions: _recognitions,
                  classColorMap: _classColorMap,
                  selectedDetectionIndex: _selectedDetectionIndex,
                  keypointConfidenceThreshold: _keypointConfidenceThreshold,
                ));
          });
    });
  }

  Widget _buildDetectionList() => ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recognitions.length,
      itemBuilder: (context, index) {
        final detection = _recognitions[index];
        final className = detection['className'] ?? 'Unknown';
        final confidence = (detection['confidence'] as num).toDouble();
        final isSelected = _selectedDetectionIndex == index;
        final itemColor = _classColorMap[className] ?? Colors.grey.shade700;
        final keypoints = detection['keypoints'] as List<Map<String, double>>?;
        final visibleKeypoints = keypoints
                ?.where((kp) =>
                    (kp['confidence'] ?? 0) > _keypointConfidenceThreshold)
                .length ??
            0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: isSelected ? 8 : 2,
          shadowColor: isSelected
              ? itemColor.withOpacity(0.5)
              : Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: itemColor, width: 2.5)
                : BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey('detection_$index'),
            onExpansionChanged: (expanded) {
              setState(() {
                _selectedDetectionIndex = expanded ? index : null;
              });
            },
            initiallyExpanded: isSelected,
            collapsedIconColor: itemColor,
            iconColor: itemColor,
            title: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: itemColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: itemColor.withOpacity(0.8), width: 1.5)),
                child: Text('${index + 1}',
                    style: TextStyle(
                        color: itemColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child:
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(className,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                    '${(confidence * 100).toStringAsFixed(1)}% Conf | $visibleKeypoints/17 Keypoints',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500)),
              ])),
            ]),
            children:
                keypoints != null ? _buildKeypointDetails(keypoints, itemColor) : [],
          ),
        );
      });

  List<Widget> _buildKeypointDetails(
      List<Map<String, double>> keypoints, Color color) {
    return List.generate(keypoints.length, (index) {
      final keypoint = keypoints[index];
      final name = _keypointNames[index];
      final confidence = keypoint['confidence'] ?? 0.0;
      final coords =
          '(${(keypoint['x'] ?? 0).toStringAsFixed(1)}, ${(keypoint['y'] ?? 0).toStringAsFixed(1)})';

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(coords,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: Colors.grey.shade300,
                    color: color,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            if (index < keypoints.length - 1) const Divider(height: 16),
          ],
        ),
      );
    });
  }

  Future<ui.Image> _loadImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void _showDeleteConfirmationDialog(String modelName) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Confirm Deletion"),
              content: Text(
                  "Are you sure you want to delete the local files for '$modelName'? This action cannot be undone."),
              actions: [
                TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.of(ctx).pop()),
                TextButton(
                    child: const Text("Delete"),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _deleteLocallyStoredModel(modelName);
                    }),
              ],
            ));
  }
}

class _DetectionPainter extends CustomPainter {
  final ui.Image originalImage;
  final List<Map<String, dynamic>> recognitions;
  final int? selectedDetectionIndex;
  final Map<String, Color> classColorMap;
  final double keypointConfidenceThreshold;

  final List<List<int>> skeletonConnections = [
    [0, 1], [0, 2], [1, 3], [2, 4],
    [5, 6], [5, 11], [6, 12], [11, 12],
    [5, 7], [7, 9],
    [6, 8], [8, 10],
    [11, 13], [13, 15],
    [12, 14], [14, 16],
  ];

  _DetectionPainter({
    required this.originalImage,
    required this.recognitions,
    required this.classColorMap,
    required this.keypointConfidenceThreshold,
    this.selectedDetectionIndex,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image first
    paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: originalImage,
        fit: BoxFit.fill);
    
    for (int i = 0; i < recognitions.length; i++) {
      final detection = recognitions[i];
      final className = detection['className'] ?? 'Unknown';
      final color = classColorMap[className] ?? Colors.grey;
      final isSelected = i == selectedDetectionIndex;
      
      // ## FIX: Scale bounding box with the canvas size ##
      final x1 = (detection['x1'] ?? 0) * size.width;
      final y1 = (detection['y1'] ?? 0) * size.height;
      final x2 = (detection['x2'] ?? 0) * size.width;
      final y2 = (detection['y2'] ?? 0) * size.height;

      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4.0 : 2.5;
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), boxPaint);

      final keypoints = detection['keypoints'] as List<Map<String, double>>?;
      if (keypoints != null) {
        // Pass the canvas size to the skeleton drawing method
        _drawSkeleton(canvas, size, keypoints, color);
      }

      final confidence = (detection['confidence'] as num? ?? 0.0);
      final textPainter = TextPainter(
          text: TextSpan(
              text: '$className (${(confidence * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
          textDirection: TextDirection.ltr);
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      final labelBackgroundPaint = Paint()
        ..color = color.withOpacity(isSelected ? 1.0 : 0.8);
      double top = y1 - textPainter.height - 4;
      if (top < 0) top = y2 + 2;
      final finalLabelRect =
          Rect.fromLTWH(x1, top, textPainter.width + 8, textPainter.height + 4);
      canvas.drawRect(finalLabelRect, labelBackgroundPaint);
      textPainter.paint(canvas, Offset(x1 + 4, top + 2));
    }
  }

  void _drawSkeleton(
      Canvas canvas, Size size, List<Map<String, double>> keypoints, Color color) {
    final skeletonPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    final keypointCircleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final keypointCircleBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final connection in skeletonConnections) {
      final p1Index = connection[0];
      final p2Index = connection[1];

      if (p1Index < keypoints.length && p2Index < keypoints.length) {
        final p1 = keypoints[p1Index];
        final p2 = keypoints[p2Index];

        if ((p1['confidence'] ?? 0) > keypointConfidenceThreshold &&
            (p2['confidence'] ?? 0) > keypointConfidenceThreshold) {
          
          // ## FIX: Scale keypoints with the canvas size ##
          canvas.drawLine(
            Offset(p1['x']! * size.width, p1['y']! * size.height),
            Offset(p2['x']! * size.width, p2['y']! * size.height),
            skeletonPaint,
          );
        }
      }
    }

    for (final keypoint in keypoints) {
      if ((keypoint['confidence'] ?? 0) > keypointConfidenceThreshold) {
        
        // ## FIX: Scale keypoints with the canvas size ##
        final point =
            Offset(keypoint['x']! * size.width, keypoint['y']! * size.height);
        canvas.drawCircle(point, 4, keypointCircleFill);
        canvas.drawCircle(point, 4, keypointCircleBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      originalImage != oldDelegate.originalImage ||
      recognitions != oldDelegate.recognitions ||
      keypointConfidenceThreshold != oldDelegate.keypointConfidenceThreshold ||
      selectedDetectionIndex != oldDelegate.selectedDetectionIndex;
}