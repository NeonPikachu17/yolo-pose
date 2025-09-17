# YOLO-POSE: Range of Motion Analyzer

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

A Flutter application designed to assist in physical therapy by analyzing a patient's Range of Motion (ROM) for specific upper-extremity exercises. The app uses the YOLO11-Pose model to perform pose estimation on user-submitted images, calculates joint angles, and provides a score based on the Fugl-Meyer Assessment for Upper Extremity (FMA-UE) scale.

## 📋 Table of Contents

- [About The Project](#about-the-project)
- [✨ Key Features](#-key-features)
- [📸 Screenshots](#-screenshots)
- [🛠️ Technology Stack & Dependencies](#️-technology-stack--dependencies)
- [📂 Project Structure](#-project-structure)
- [🚀 Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [ How It Works: The Analysis Pipeline](#-how-it-works-the-analysis-pipeline)

## About The Project

Physical therapy often requires precise measurement of a patient's ability to perform certain movements. This app automates the assessment process by allowing a user to upload "start" and "end" photos for a given exercise. It then leverages a pre-trained machine learning model to detect key body joints, calculate the range of motion, and provide immediate, quantitative feedback.


## ✨ Key Features

- **AI-Powered Pose Estimation**: Utilizes a YOLO11-Pose model (`yolo11m-pose_float32.tflite`) to accurately detect 17 key body points from a static image.
- **Automated Exercise Scoring**: Implements scoring logic for several FMA-UE exercises, including Shoulder Abduction, Shoulder Flexion, and Hand to Lumbar Spine.
- **Range of Motion Calculation**: Precisely calculates the angle between relevant joints (e.g., hip-shoulder-elbow) to determine the achieved range of motion.
- **Visual Feedback**: Overlays the detected keypoints and angle lines directly onto the user's images, providing clear visual confirmation of the analysis.
- **Detailed Results Summary**: Presents a comprehensive summary screen with an overall session score and a detailed breakdown for each exercise, including key metrics like Start Angle, End Angle, and ROM.
- **Robust Image Handling**: Includes image orientation normalization to correctly handle photos from any device or camera orientation.
- **Intuitive User Interface**: A clean, modern UI built with Material 3, custom themes, and `google_fonts` for a polished user experience.

## 📸 Screenshots

| Home Screen | Image Upload Sheet | Detailed Analysis View | Results Summary |
| :---: | :---: | :---: | :---: |
| <img src="https://via.placeholder.com/300x600.png?text=Home+Screen" alt="Home Screen" width="200"/> | <img src="https://via.placeholder.com/300x600.png?text=Upload+Sheet" alt="Upload Sheet" width="200"/> | <img src="https://via.placeholder.com/300x600.png?text=Analysis+View" alt="Analysis View" width="200"/> | <img src="https://via.placeholder.com/300x600.png?text=Summary+Screen" alt="Summary Screen" width="200"/> |


## 🛠️ Technology Stack & Dependencies

- **Framework**: Flutter 3.x
- **Language**: Dart
- **AI/ML Model**: YOLO11M-Pose (`.tflite` format)
- **Core Packages**:
  - `ultralytics_yolo`: For running inference with the YOLO model on-device.
  - `image_picker`: For selecting start and end position images from the gallery.
  - `image`: For advanced image processing, specifically for normalizing EXIF orientation.
  - `path_provider` & `path`: For managing file paths and storing the ML model locally.
  - `google_fonts`: For custom typography.
- **State Management**: `StatefulWidget` with `setState`.

## 📂 Project Structure

The project is organized into several key files to maintain a clean architecture:

```
lib/
├── assets/
│   ├── images/
│   │   ├── ShoulderAbduction.png
│   │   └── ... (other exercise images)
│   └── models/
│       └── yolo11m-pose_float32.tflite  # The core pose estimation model
│
├── body_side.dart               # Enum for selecting Left/Right body side
├── exercise_upload_sheet.dart   # UI for the modal bottom sheet where users upload photos
├── main.dart                    # App entry point, theme configuration, and main widget
├── results_summary_screen.dart  # UI for the final summary page with a score gauge
├── submitted_photos_screen.dart # UI for the detailed analysis of a single exercise
└── therapy_home_screen.dart     # Main screen with the list of exercises and core logic
```

## 🚀 Getting Started

Follow these instructions to get a local copy up and running for development and testing.

### Prerequisites

- Flutter SDK (version 3.0 or higher)
- An IDE like Android Studio or VS Code with the Flutter plugin.
- A physical Android/iOS device or a configured emulator/simulator.

### Installation

1.  **Clone the repository:**
    ```sh
    git clone [https://github.com/NeonPikachu17/yolo-pose.git](https://github.com/NeonPikachu17/yolo-pose.git)
    cd pose-vision-ai
    ```

2.  **Ensure Assets are Correctly Placed:**
    - The YOLO model `yolo11m-pose_float32.tflite` must be located in the `assets/models/` directory.
    - The exercise images (e.g., `ShoulderAbduction.png`) must be in the `assets/images/` directory.

3.  **Configure `pubspec.yaml`:**
    Make sure your `pubspec.yaml` file includes the assets so Flutter can bundle them with the app.

    ```yaml
    flutter:
      uses-material-design: true
      assets:
        - assets/models/
        - assets/images/
    ```

4.  **Install dependencies:**
    Run the following command in your terminal:
    ```sh
    flutter pub get
    ```

5.  **Run the application:**
    ```sh
    flutter run
    ```

##  How It Works: The Analysis Pipeline

The application follows a clear, multi-step process to analyze an exercise:

1.  **Image Selection**: The user selects an exercise from the `TherapyHomeScreen` and is prompted by the `ExerciseUploadSheet` to pick "start" and "end" position images and select the body side (left/right).

2.  **Pose Estimation**: When the user taps "Analyze," the `_analyzeAndScoreExercise` function is triggered.
    - The `ultralytics_yolo` package loads the `.tflite` model.
    - The model runs inference on both the start and end images, returning a list of 17 keypoints (e.g., shoulders, elbows, wrists) with their (x, y) coordinates and a confidence score for each.

3.  **Angle Calculation**:
    - Based on the exercise and selected body side, the app identifies the three specific keypoints needed to calculate the relevant joint angle (e.g., for shoulder abduction, it uses the hip, shoulder, and elbow).
    - The `_calculateAngle` helper function computes the angle in degrees using the $atan2$ trigonometric formula.

4.  **Scoring**:
    - A dedicated scoring function for each exercise (e.g., `_scoreShoulderAbduction`) compares the calculated `endAngle` against clinically-inspired thresholds.
    - It assigns a score of **2** (full motion), **1** (partial motion), or **0** (no/minimal motion).

5.  **Displaying Results**:
    - The results, including the score, calculated angles, and keypoint data, are stored and displayed.
    - The `SubmittedPhotosScreen` uses a `CustomPainter` (`KeypointPainter`) to draw the joints and connecting lines over the images, providing powerful visual feedback.
    - The `ResultsSummaryScreen` aggregates the scores from all completed exercises into a final FMA-UE score.