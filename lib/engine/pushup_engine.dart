import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise_stats.dart';
import 'exercise_engine.dart';

enum PushupPhase { standing, descending, bottom, ascending }

class PushupEngine extends ExerciseEngine {
  @override
  String get exerciseName => "Push-up";

  @override
  String get incorrectFeedbackVoice => "ลงให้ลึกกว่านี้";

  @override
  String get visibilityWarningText => "กรุณาจัดมุมกล้องด้านข้างให้เห็นทั้งลำตัว";

  PushupPhase _currentPhase = PushupPhase.standing;
  int _correctReps = 0;
  int _incorrectReps = 0;
  double _minElbowAngleInRep = 180.0;
  bool _faultHipOccurred = false;

  // เกณฑ์มาตรฐาน Push-up
  static const double standElbowThreshold = 150.0;  // แขนตึงเตรียมพร้อม
  static const double targetDepthThreshold = 90.0;   // ข้อศอกทำมุมฉาก 90 องศา
  static const double descentThreshold = 130.0;      // เริ่มงอศอกลง
  static const double minHipAngle = 145.0;           // หลังต้องตรง ไม่งอ/แอ่น

  @override
  void reset() {
    _currentPhase = PushupPhase.standing;
    _correctReps = 0;
    _incorrectReps = 0;
    _minElbowAngleInRep = 180.0;
    _faultHipOccurred = false;
  }

  void _resetFaults() {
    _faultHipOccurred = false;
  }

  @override
  ExerciseStats processPose(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final double leftLikelihood = (leftShoulder?.likelihood ?? 0) +
        (leftElbow?.likelihood ?? 0) +
        (leftWrist?.likelihood ?? 0);
    final double rightLikelihood = (rightShoulder?.likelihood ?? 0) +
        (rightElbow?.likelihood ?? 0) +
        (rightWrist?.likelihood ?? 0);

    final bool useLeft = leftLikelihood >= rightLikelihood;
    final shoulder = useLeft ? leftShoulder : rightShoulder;
    final elbow = useLeft ? leftElbow : rightElbow;
    final wrist = useLeft ? leftWrist : rightWrist;
    final hip = useLeft ? leftHip : rightHip;
    final ankle = useLeft ? leftAnkle : rightAnkle;

    final bool isBodyInFrame = shoulder != null &&
        elbow != null &&
        wrist != null &&
        hip != null &&
        shoulder.likelihood > 0.45 &&
        elbow.likelihood > 0.45 &&
        wrist.likelihood > 0.45;

    if (!isBodyInFrame) {
      return ExerciseStats(
        totalReps: _correctReps + _incorrectReps,
        correctReps: _correctReps,
        incorrectReps: _incorrectReps,
        currentAngle: 0.0,
        isBodyInFrame: false,
        state: ExerciseMovementState.neutral,
        feedback: visibilityWarningText,
      );
    }

    final double elbowAngle = _calculateAngle(shoulder, elbow, wrist);
    final double hipAngle = (hip != null && ankle != null)
        ? _calculateAngle(shoulder, hip, ankle)
        : 180.0;

    switch (_currentPhase) {
      case PushupPhase.standing:
        if (elbowAngle <= descentThreshold) {
          _currentPhase = PushupPhase.descending;
          _minElbowAngleInRep = elbowAngle;
          _resetFaults();

          if (hipAngle < minHipAngle) _faultHipOccurred = true;
        }
        break;

      case PushupPhase.descending:
        if (elbowAngle < _minElbowAngleInRep) {
          _minElbowAngleInRep = elbowAngle;
        }
        if (hipAngle < minHipAngle) _faultHipOccurred = true;

        if (elbowAngle <= targetDepthThreshold) {
          _currentPhase = PushupPhase.bottom;
        } else if (elbowAngle > _minElbowAngleInRep + 15.0) {
          _currentPhase = PushupPhase.ascending;
        }
        break;

      case PushupPhase.bottom:
        if (elbowAngle < _minElbowAngleInRep) {
          _minElbowAngleInRep = elbowAngle;
        }
        if (hipAngle < minHipAngle) _faultHipOccurred = true;

        if (elbowAngle > targetDepthThreshold + 10.0) {
          _currentPhase = PushupPhase.ascending;
        }
        break;

      case PushupPhase.ascending:
        if (hipAngle < minHipAngle) _faultHipOccurred = true;

        if (elbowAngle >= standElbowThreshold) {
          if (_minElbowAngleInRep <= targetDepthThreshold && !_faultHipOccurred) {
            _correctReps++;
          } else {
            _incorrectReps++;
          }

          _currentPhase = PushupPhase.standing;
          _minElbowAngleInRep = 180.0;
          _resetFaults();
        }
        break;
    }

    String feedbackText = "ดีมาก";
    if (_faultHipOccurred) {
      feedbackText = "เกร็งลำตัวให้ตรง";
    } else if (elbowAngle > targetDepthThreshold) {
      feedbackText = "ลงให้ลึกกว่านี้";
    }

    return ExerciseStats(
      totalReps: _correctReps + _incorrectReps,
      correctReps: _correctReps,
      incorrectReps: _incorrectReps,
      currentAngle: elbowAngle,
      isBodyInFrame: true,
      state: ExerciseMovementState.neutral,
      feedback: feedbackText,
    );
  }

  double _calculateAngle(
    PoseLandmark first,
    PoseLandmark middle,
    PoseLandmark last,
  ) {
    final double radians = math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);
    double angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  @override
  void paintOverlay(
    Canvas canvas,
    Size size,
    Pose pose,
    double currentAngle,
    Offset Function(double x, double y, Size size) translatePoint,
  ) {
    final armPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    final jointGlowPaint = Paint()
      ..color = const Color(0xFF1DE9B6)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    final bool useLeft =
        (leftElbow?.likelihood ?? 0) >= (rightElbow?.likelihood ?? 0);

    final shoulder = pose.landmarks[
        useLeft ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder];
    final elbow = useLeft ? leftElbow : rightElbow;
    final wrist = pose.landmarks[
        useLeft ? PoseLandmarkType.leftWrist : PoseLandmarkType.rightWrist];

    if (shoulder != null &&
        elbow != null &&
        wrist != null &&
        shoulder.likelihood > 0.4 &&
        elbow.likelihood > 0.4 &&
        wrist.likelihood > 0.4) {
      final pShoulder = translatePoint(shoulder.x, shoulder.y, size);
      final pElbow = translatePoint(elbow.x, elbow.y, size);
      final pWrist = translatePoint(wrist.x, wrist.y, size);

      canvas.drawLine(pShoulder, pElbow, armPaint);
      canvas.drawLine(pElbow, pWrist, armPaint);

      canvas.drawCircle(pElbow, 7.0, jointGlowPaint);
      canvas.drawCircle(pElbow, 7.0, outlinePaint);

      _drawAngleBadge(canvas, pElbow, currentAngle);
    }
  }

  void _drawAngleBadge(Canvas canvas, Offset position, double angle) {
    final bool isTargetReached = angle <= targetDepthThreshold;
    final textSpan = TextSpan(
      text: "${angle.toStringAsFixed(0)}°",
      style: TextStyle(
        color: isTargetReached ? const Color(0xFF00E676) : Colors.amberAccent,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.dx + 35, position.dy - 10),
        width: textPainter.width + 14,
        height: textPainter.height + 6,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(badgeRect, Paint()..color = Colors.black87);
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = isTargetReached ? const Color(0xFF00E676) : Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    textPainter.paint(canvas, Offset(badgeRect.left + 7, badgeRect.top + 3));
  }
}