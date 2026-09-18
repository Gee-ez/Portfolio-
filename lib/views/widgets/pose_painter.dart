import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../engine/exercise_engine.dart';
import 'coordinates_translator.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final double currentAngle;
  final ExerciseEngine engine;

  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    required this.currentAngle,
    required this.engine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final jointOutlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pose in poses) {
      _drawFullSkeleton(canvas, size, pose, bodyLinePaint);

      pose.landmarks.forEach((_, landmark) {
        if (landmark.likelihood > 0.4) {
          final point = _translatePoint(landmark.x, landmark.y, size);
          canvas.drawCircle(point, 5.5, jointPaint);
          canvas.drawCircle(point, 5.5, jointOutlinePaint);
        }
      });

      engine.paintOverlay(canvas, size, pose, currentAngle, _translatePoint);
    }
  }

  void _drawFullSkeleton(Canvas canvas, Size size, Pose pose, Paint paint) {
    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = pose.landmarks[type1];
      final p2 = pose.landmarks[type2];
      if (p1 != null && p2 != null && p1.likelihood > 0.4 && p2.likelihood > 0.4) {
        canvas.drawLine(
          _translatePoint(p1.x, p1.y, size),
          _translatePoint(p2.x, p2.y, size),
          paint,
        );
      }
    }

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  Offset _translatePoint(double x, double y, Size size) {
    return Offset(
      translateX(x, size, imageSize, rotation, cameraLensDirection),
      translateY(y, size, imageSize, rotation, cameraLensDirection),
    );
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}