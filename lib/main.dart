import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  // It's good practice to ensure Flutter bindings are initialized,
  // especially if you're doing async work before runApp or using plugins extensively.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOLO Detection App',
      theme: ThemeData(
        primarySwatch: Colors.blue, // You can customize your theme
        useMaterial3: true, // Optional: if you want to use Material 3 features
      ),
      home: const DetectionScreen(), // This sets your DetectionScreen as the initial screen
    );
  }
}

// Helper function
Future<String> getAbsolutePath(String assetPath) async {
  final tempDir = await getTemporaryDirectory();
  final fileName = p.basename(assetPath);
  final tempPath = p.join(tempDir.path, fileName);
  try {
    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    await File(tempPath).writeAsBytes(buffer, flush: true);
    debugPrint("Copied asset $assetPath to $tempPath");
    return tempPath;
  } catch (e) {
    debugPrint("Error copying asset $assetPath: $e");
    throw Exception("Failed to copy asset: $assetPath");
  }
}

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  YOLO? _yoloModel;
  File? _imageFile;
  List<Map<String, dynamic>> _recognitions = []; // Non-nullable
  bool _isLoading = false;
  String? _selectedModelName;
  String? _currentModelPath;
  Uint8List? _annotatedImageBytes;

  // Define a list of colors for bounding boxes
  final List<Color> _boxColors = [
    Colors.red, Colors.blue, Colors.green, Colors.yellow.shade700, // Use darker yellow for visibility
    Colors.purple, Colors.orange, Colors.pink, Colors.teal,
    Colors.cyan, Colors.brown, Colors.amber.shade700, Colors.indigo,
    Colors.lime.shade700, Colors.lightGreen.shade700, Colors.deepOrange, Colors.blueGrey
  ];

  final List<Map<String, String>> _availableModels = [
    {
      'name': 'YOLOv8n16',
      'modelAssetPath': 'assets/models/yolov8n16.tflite',
      'labelsAssetPath': 'assets/models/labels.txt',
    },
    {
      'name': 'YOLOv8n32',
      'modelAssetPath': 'assets/models/yolov8n32.tflite',
      'labelsAssetPath': 'assets/models/labels.txt',
    },
    {
      'name': 'YOLOv11n16',
      'modelAssetPath': 'assets/models/yolo11n16.tflite',
      'labelsAssetPath': 'assets/models/labels.txt',
    },
    {
      'name': 'YOLOv11n32',
      'modelAssetPath': 'assets/models/yolo11n32.tflite',
      'labelsAssetPath': 'assets/models/labels.txt',
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _yoloModel?.dispose();
    super.dispose();
  }

  Future<void> _prepareAndLoadModel(Map<String, String> modelData) async {
    if (modelData['modelAssetPath'] == null || modelData['labelsAssetPath'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Model or labels asset path is missing.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recognitions = [];
      _annotatedImageBytes = null;
    });

    try {
      final modelAbsolutePath = await getAbsolutePath(modelData['modelAssetPath']!);
      final labelsAbsolutePath = await getAbsolutePath(modelData['labelsAssetPath']!);

      _yoloModel = YOLO(
        modelPath: modelAbsolutePath,
        task: YOLOTask.detect,
      );
      await _yoloModel?.loadModel();

      setState(() {
        _selectedModelName = modelData['name'];
        _currentModelPath = modelAbsolutePath;
        _yoloModel = _yoloModel;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$_selectedModelName loaded successfully.")),
      );
    } catch (e) {
      debugPrint("Error loading model: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading model: ${modelData['name']}. Details: $e")),
      );
      setState(() {
        _yoloModel = null;
        _selectedModelName = null;
        _currentModelPath = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _recognitions = [];
        _annotatedImageBytes = null;
      });

      if (_yoloModel != null) {
        _runDetection();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select and load a model first.")),
        );
      }
    }
  }

  Future<void> _runDetection() async {
    if (_imageFile == null || _yoloModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image selected or model not loaded.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final imageBytes = await _imageFile!.readAsBytes();
      final detections = await _yoloModel!.predict(imageBytes);

      // debugPrint("------- RAW PREDICTION OUTPUT START -------");
      // debugPrint("Type: ${detections.runtimeType}");
      // debugPrint("Content: $detections");
      // debugPrint("------- RAW PREDICTION OUTPUT END -------");

      // Now, try to process it
      // if (detections is Map) {
      //     final dynamic rawDetectionsList = detections;
      //     debugPrint("------- RAW DETECTIONS LIST START -------");
      //     debugPrint("Type: ${rawDetectionsList.runtimeType}");
      //     debugPrint("Content: $rawDetectionsList");
      //     debugPrint("------- RAW DETECTIONS LIST END -------");

      //     if (rawDetectionsList is List && rawDetectionsList.isNotEmpty) {
      //         // Further parsing logic here...
      //         // For now, just confirm you got a list
      //     } else if (rawDetectionsList == null) {
      //         debugPrint("'detections' key was null or not found in the map.");
      //     } else if (rawDetectionsList is List && rawDetectionsList.isEmpty) {
      //         debugPrint("'detections' key returned an empty list from the plugin.");
      //     }


      //     // Your existing setState logic can follow, but the prints above will tell you what you received
      //     setState(() {
      //       if (rawDetectionsList is List) {
      //         // Assuming YOLOResult has a way to be created from items in rawDetectionsList
      //         // This part needs to be robust
      //         _recognitions = rawDetectionsList.map((item) {
      //           try {
      //             // Example: if YOLOResult has a factory constructor fromMap
      //             return YOLOResult.fromMap(item as Map<String, dynamic>);
      //           } catch (e) {
      //             debugPrint("Error converting item to YOLOResult: $e. Item: $item");
      //             return null; // Or handle error appropriately
      //           }
      //         }).whereType<YOLOResult>().toList(); // Filter out nulls if parsing failed for some items
      //       } else {
      //         _recognitions = [];
      //       }
      //       _annotatedImageBytes = detections['annotatedImage'] as Uint8List?;
      //     });

      // } else {
      //     debugPrint("Prediction output was not a Map as expected.");
      //     setState((){ _recognitions = []; _annotatedImageBytes = null; });
      // }

      setState(() {
        _recognitions = detections['boxes'] ?? [];
        _annotatedImageBytes = detections['annotatedImage'] as Uint8List?;
      });

      if (_recognitions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No objects detected.")),
        );
      }
    } catch (e) {
      debugPrint("Error running detection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during detection: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildModelSelector() {
    return DropdownButton<String>(
      hint: const Text("Select a Model to Load"),
      value: _selectedModelName,
      isExpanded: true,
      items: _availableModels.map((model) {
        return DropdownMenuItem<String>(
          value: model['name'],
          child: Text(model['name']!),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          final selectedModelData = _availableModels.firstWhere((m) => m['name'] == newValue);
          _prepareAndLoadModel(selectedModelData);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ultralytics YOLO Detection"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildModelSelector(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Pick Image from Gallery"),
              onPressed: _pickImage,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_imageFile != null) ...[
              Text("Original Image", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Image.file(_imageFile!), // Display the original image
              const SizedBox(height: 20),
              Text("Original Image with Detections", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _buildImageWithDetections(_imageFile!, _recognitions),
              const SizedBox(height: 20),
              
              if (_annotatedImageBytes != null) ...[
                Text("Annotated Image", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Image.memory(_annotatedImageBytes!),
                const SizedBox(height: 20),
              ],
              
              if (_recognitions.isNotEmpty)
                Text("Detections: ${_recognitions.length}", style: Theme.of(context).textTheme.titleMedium),
              if (_recognitions.isNotEmpty)
                _buildDetectionList(),
            ] else
              const Center(child: Text("Select an image and load a model to begin.")),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithDetections(File imageFile, List<Map<String, dynamic>> recognitions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Image.file(imageFile),
            ...recognitions.asMap().entries.map((entry) { // Use asMap().entries.map to get index
              final int index = entry.key;
              final Map<String, dynamic> det = entry.value;
              
              // Cycle through your colors list
              final Color boxColor = _boxColors[index % _boxColors.length];

              // Safely extract values
              final double x1 = (det['x1'] as num?)?.toDouble() ?? 0.0;
              final double y1 = (det['y1'] as num?)?.toDouble() ?? 0.0;
              final double x2 = (det['x2'] as num?)?.toDouble() ?? 0.0;
              final double y2 = (det['y2'] as num?)?.toDouble() ?? 0.0;
              final String className = det['class']?.toString() ?? 'Unknown';
              final double confidence = (det['confidence'] as num?)?.toDouble() ?? 0.0;

              final double boxWidth = x2 - x1;
              final double boxHeight = y2 - y1;

              if (boxWidth <= 0 || boxHeight <= 0) {
                // debugPrint("Skipping invalid box: $det"); // Optional: for debugging
                return const SizedBox.shrink(); // Don't draw invalid boxes
              }

              return Positioned(
                left: x1,
                top: y1,
                width: boxWidth,
                height: boxHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: boxColor, width: 2.5), // Use dynamic color
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      color: boxColor.withOpacity(0.6), // Use dynamic color with opacity
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        "$className (${(confidence * 100).toStringAsFixed(1)}%)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildDetectionList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recognitions.length,
      itemBuilder: (context, index) {
        final detection = _recognitions[index];
        
        final className = detection['class']?.toString() ?? 'Unknown';
        final confidence = (detection['confidence'] as num?)?.toDouble() ?? 0.0;
        final x1 = (detection['x1'] as num?)?.toDouble() ?? 0.0;
        final y1 = (detection['y1'] as num?)?.toDouble() ?? 0.0;
        // For display, use the actual x2 and y2 coordinates, not width/height
        final x2_coord = (detection['x2'] as num?)?.toDouble() ?? 0.0; 
        final y2_coord = (detection['y2'] as num?)?.toDouble() ?? 0.0;

        // Calculate width and height separately if needed for display, or just show x1,y1,x2,y2
        final boxWidth = x2_coord - x1;
        final boxHeight = y2_coord - y1;


        return Card(
          child: ListTile(
            title: Text(className),
            subtitle: Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
            // Displaying x1,y1 and width,height for clarity. You can choose x1,y1,x2,y2 too.
            trailing: Text('Box: (${x1.toStringAsFixed(0)},${y1.toStringAsFixed(0)}) W:${boxWidth.toStringAsFixed(0)},H:${boxHeight.toStringAsFixed(0)}'),
          ),
        );
      },
    );
  }
}