// lib/exercise_upload_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'therapy_home_screen.dart'; 
import 'body_side.dart';

class ExerciseUploadSheet extends StatefulWidget {
  final Exercise exercise;
  final Function(String, String, File, BodySide) onImageUploaded;

  const ExerciseUploadSheet({
    super.key,
    required this.exercise,
    required this.onImageUploaded,
  });

  @override
  State<ExerciseUploadSheet> createState() => _ExerciseUploadSheetState();
}

class _ExerciseUploadSheetState extends State<ExerciseUploadSheet> {
  File? _startImage;
  File? _endImage;
  BodySide _selectedSide = BodySide.right;

  Future<void> _pickImage(ImageSource source, Function(File) onSelect) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      // --- INTEGRATION POINT ---
      // Instead of using the file directly, first normalize it.
      final normalizedImageFile = await _normalizeImageOrientation(pickedFile.path);
      onSelect(normalizedImageFile); // Use the corrected file
      // --- END OF FIX ---
    }
  }

  Future<File> _normalizeImageOrientation(String imagePath) async {
    // Read the original image file as bytes
    final imageBytes = await File(imagePath).readAsBytes();

    // Decode the image using the 'image' package
    final originalImage = img.decodeImage(imageBytes);

    // If the image can't be decoded, return the original file
    if (originalImage == null) {
      return File(imagePath);
    }

    // The magic happens here: bakeOrientation reads the EXIF orientation
    // and applies the necessary rotation/flipping to the image pixels.
    final fixedImage = img.bakeOrientation(originalImage);

    // Get a temporary directory to save the new file
    final directory = await getTemporaryDirectory();
    final newPath = p.join(directory.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final newFile = File(newPath);

    // Encode the fixed image to JPEG format and write it to the new file
    await newFile.writeAsBytes(img.encodeJpg(fixedImage));

    return newFile;
  }

  @override
  Widget build(BuildContext context) {
    final canAnalyze = _startImage != null && _endImage != null;

    // MODIFIED: Wrapped the content in a Container to provide the background
    // and rounded corners for the sheet.
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.exercise.title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.exercise.instructions, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade700)),
            const Divider(height: 32),
            Text("SELECT BODY SIDE", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            SegmentedButton<BodySide>(
              segments: const [
                ButtonSegment(value: BodySide.left, label: Text("Left"), icon: Icon(Icons.front_hand)),
                ButtonSegment(value: BodySide.right, label: Text("Right"), icon: Icon(Icons.front_hand_outlined)),
              ],
              selected: {_selectedSide},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedSide = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Colors.black.withOpacity(0.1),
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildImagePicker("START", _startImage, (file) => setState(() {
                  _startImage = file;
                  widget.onImageUploaded(widget.exercise.title, 'start', file, _selectedSide);
                })),
                const SizedBox(width: 16),
                _buildImagePicker("END", _endImage, (file) => setState(() {
                  _endImage = file;
                  widget.onImageUploaded(widget.exercise.title, 'end', file, _selectedSide);
                })),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: canAnalyze ? () => Navigator.of(context).pop(true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text("Analyze", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(String label, File? imageFile, Function(File) onSelect) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1.0,
            child: InkWell(
              onTap: () => _pickImage(ImageSource.gallery, onSelect),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  image: imageFile != null ? DecorationImage(image: FileImage(imageFile), fit: BoxFit.cover) : null,
                ),
                child: imageFile == null ? const Center(child: Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey)) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}