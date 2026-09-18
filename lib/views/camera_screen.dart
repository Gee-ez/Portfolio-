import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../engine/exercise_engine.dart';
import '../models/exercise_stats.dart';
import '../core/audio/audio_feedback_service.dart';
import 'widgets/pose_painter.dart';
import 'summary_screen.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final ExerciseEngine engine;

  const CameraScreen({
    super.key,
    required this.camera,
    required this.engine,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  final AudioFeedbackService _audioService = AudioFeedbackService();

  bool _isDetecting = false;
  bool _isSessionActive = false;
  bool _isPaused = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  List<Pose> _detectedPoses = [];
  ExerciseStats _stats = ExerciseStats.initial();
  int _previousRepCount = 0;

  DateTime? _sessionStartTime;
  int _totalPausedSeconds = 0;
  DateTime? _pauseStartTime;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _initDetector();
    _initCamera();
  }

  Future<void> _initAudio() async {
    await _audioService.init();
  }

  void _initDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.startImageStream((CameraImage image) {
        if (!_isDetecting && _controller != null && mounted) {
          _processCameraImage(image);
        }
      });

      setState(() {});
    } catch (e) {
      debugPrint("Camera initialize error: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final poses = await _poseDetector?.processImage(inputImage);

      if (mounted) {
        if (poses == null || poses.isEmpty) {
          setState(() {
            _detectedPoses = [];
          });
        } else {
          final newStats = widget.engine.processPose(poses.first);

          if (_isSessionActive && !_isPaused && _countdown == 0) {
            if (newStats.totalReps > _previousRepCount) {
              _previousRepCount = newStats.totalReps;
              if (newStats.correctReps > _stats.correctReps) {
                _audioService.speak("${newStats.correctReps}");
              } else {
                _audioService.speak(widget.engine.incorrectFeedbackVoice);
              }
            }
          }

          setState(() {
            _detectedPoses = poses;
            _stats = newStats;
          });
        }
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = widget.camera;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _startWorkout() {
    setState(() {
      _countdown = 3;
      _isSessionActive = true;
      _isPaused = false;
      _sessionStartTime = DateTime.now();
      _totalPausedSeconds = 0;
      _pauseStartTime = null;
      widget.engine.reset();
      _stats = ExerciseStats.initial();
      _previousRepCount = 0;
    });

    _audioService.speak("3");
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        _audioService.speak("$_countdown");
      } else {
        timer.cancel();
        setState(() {
          _countdown = 0;
        });
        _audioService.speak("เริ่มได้!");
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pauseStartTime = DateTime.now();
      } else {
        if (_pauseStartTime != null) {
          _totalPausedSeconds +=
              DateTime.now().difference(_pauseStartTime!).inSeconds;
          _pauseStartTime = null;
        }
      }
    });

    if (_isPaused) {
      _audioService.speak("พักชั่วคราว");
    } else {
      _audioService.speak("ลุยต่อ");
    }
  }

  void _finishWorkout() {
    Duration workoutDuration = Duration.zero;
    if (_sessionStartTime != null) {
      final totalElapsed = DateTime.now().difference(_sessionStartTime!).inSeconds;
      final activeSeconds = totalElapsed - _totalPausedSeconds;
      workoutDuration = Duration(seconds: activeSeconds > 0 ? activeSeconds : 0);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          exerciseName: widget.engine.exerciseName,
          total: _stats.totalReps,
          correct: _stats.correctReps,
          incorrect: _stats.incorrectReps,
          duration: workoutDuration,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller?.dispose();
    _poseDetector?.close();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. ส่วนกล้องและ CustomPaint แมปพิกัดตามมาตรฐาน Official ML Kit
          SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
  scaleX: widget.camera.lensDirection == CameraLensDirection.front ? -1.0 : 1.0,
  alignment: Alignment.center,
  child: CameraPreview(_controller!),
),
                if (_detectedPoses.isNotEmpty && _stats.isBodyInFrame)
                  CustomPaint(
                    painter: PosePainter(
                      poses: _detectedPoses,
                      imageSize: Size(
                        _controller!.value.previewSize!.width,
                        _controller!.value.previewSize!.height,
                      ),
                      rotation: InputImageRotationValue.fromRawValue(
                              widget.camera.sensorOrientation) ??
                          InputImageRotation.rotation90deg,
                      cameraLensDirection: widget.camera.lensDirection,
                      currentAngle: _stats.currentAngle,
                      engine: widget.engine,
                    ),
                  ),
              ],
            ),
          ),

          // 2. ป้ายเตือนหลุดเฟรม
          if (_isSessionActive && _countdown == 0 && !_stats.isBodyInFrame)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.accessibility_new_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.engine.visibilityWarningText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. แถบสถิติด้านบน (HUD)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      _buildMiniStat("CORRECT", "${_stats.correctReps}", Colors.greenAccent),
                      const SizedBox(width: 16),
                      _buildMiniStat("FIX", "${_stats.incorrectReps}", Colors.orangeAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. ตัวเลขนับถอยหลัง
          if (_countdown > 0)
            Center(
              child: Text(
                "$_countdown",
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 110,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 20),
                  ],
                ),
              ),
            ),

          // 5. แผงปุ่มควบคุมด้านล่าง
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _isSessionActive
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _togglePause,
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(_isPaused ? "RESUME" : "PAUSE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPaused ? Colors.green : Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _finishWorkout,
                          icon: const Icon(Icons.stop),
                          label: const Text("FINISH"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startWorkout,
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                      label: Text(
                        "START ${widget.engine.exerciseName.toUpperCase()} SESSION",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}