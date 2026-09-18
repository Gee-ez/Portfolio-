import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise_stats.dart';
import 'exercise_engine.dart';

enum SquatPhase { standing, descending, bottom, ascending }

class SquatEngine extends ExerciseEngine {
  @override
  String get exerciseName => "Squat";

  @override
  String get incorrectFeedbackVoice => "ย่อลงอีก";

  @override
  String get visibilityWarningText => "กรุณายืนให้เห็นข้อต่อตั้งแต่สะโพกถึงปลายเท้าทั้งสองข้าง";

  SquatPhase _currentPhase = SquatPhase.standing;
  double _minKneeAngleInRep = 180.0;
  int _correctReps = 0;
  int _incorrectReps = 0;

  static const double standThreshold = 160.0;
  static const double shallowThreshold = 120.0;
  static const double targetDepthThreshold = 95.0;

  @override
  void reset() {
    _currentPhase = SquatPhase.standing;
    _minKneeAngleInRep = 180.0;
    _correctReps = 0;
    _incorrectReps = 0;
  }

  ExerciseMovementState _mapPhaseToState(SquatPhase phase) {
    return ExerciseMovementState.neutral;
  }

  @override
  ExerciseStats processPose(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final bool isLeftLegVisible = leftHip != null && leftKnee != null && leftAnkle != null &&
        leftHip.likelihood > 0.45 && leftKnee.likelihood > 0.45 && leftAnkle.likelihood > 0.45;

    final bool isRightLegVisible = rightHip != null && rightKnee != null && rightAnkle != null &&
        rightHip.likelihood > 0.45 && rightKnee.likelihood > 0.45 && rightAnkle.likelihood > 0.45;

    final bool isBodyInFrame = isLeftLegVisible || isRightLegVisible;

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

    final double leftAngle = isLeftLegVisible
        ? _calculateAngle(leftHip, leftKnee, leftAnkle)
        : 180.0;
    final double rightAngle = isRightLegVisible
        ? _calculateAngle(rightHip, rightKnee, rightAnkle)
        : 180.0;

    double currentKneeAngle;
    if (isLeftLegVisible && isRightLegVisible) {
      currentKneeAngle = (leftAngle + rightAngle) / 2.0;
    } else if (isLeftLegVisible) {
      currentKneeAngle = leftAngle;
    } else {
      currentKneeAngle = rightAngle;
    }

    switch (_currentPhase) {
      case SquatPhase.standing:
        if (currentKneeAngle < shallowThreshold) {
          _currentPhase = SquatPhase.descending;
          _minKneeAngleInRep = currentKneeAngle;
        }
        break;

      case SquatPhase.descending:
        if (currentKneeAngle < _minKneeAngleInRep) {
          _minKneeAngleInRep = currentKneeAngle;
        }
        if (currentKneeAngle <= targetDepthThreshold) {
          _currentPhase = SquatPhase.bottom;
        } else if (currentKneeAngle > _minKneeAngleInRep + 15.0) {
          _currentPhase = SquatPhase.ascending;
        }
        break;

      case SquatPhase.bottom:
        if (currentKneeAngle < _minKneeAngleInRep) {
          _minKneeAngleInRep = currentKneeAngle;
        }
        if (currentKneeAngle > targetDepthThreshold + 10.0) {
          _currentPhase = SquatPhase.ascending;
        }
        break;

      case SquatPhase.ascending:
        if (currentKneeAngle >= standThreshold) {
          if (_minKneeAngleInRep <= targetDepthThreshold) {
            _correctReps++;
          } else {
            _incorrectReps++;
          }

          _currentPhase = SquatPhase.standing;
          _minKneeAngleInRep = 180.0;
        }
        break;
    }

    return ExerciseStats(
      totalReps: _correctReps + _incorrectReps,
      correctReps: _correctReps,
      incorrectReps: _incorrectReps,
      currentAngle: currentKneeAngle,
      isBodyInFrame: true,
      state: _mapPhaseToState(_currentPhase),
      feedback: currentKneeAngle <= targetDepthThreshold ? "ดีมาก" : "ย่อลงอีก",
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
    final legHighlightPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final jointGlowPaint = Paint()
      ..color = const Color(0xFF1DE9B6)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    void highlightLeg(
      PoseLandmarkType hipType,
      PoseLandmarkType kneeType,
      PoseLandmarkType ankleType,
    ) {
      final hip = pose.landmarks[hipType];
      final knee = pose.landmarks[kneeType];
      final ankle = pose.landmarks[ankleType];

      if (hip != null && knee != null && ankle != null &&
          hip.likelihood > 0.4 && knee.likelihood > 0.4 && ankle.likelihood > 0.4) {
        final hipPoint = translatePoint(hip.x, hip.y, size);
        final kneePoint = translatePoint(knee.x, knee.y, size);
        final anklePoint = translatePoint(ankle.x, ankle.y, size);

        canvas.drawLine(hipPoint, kneePoint, legHighlightPaint);
        canvas.drawLine(kneePoint, anklePoint, legHighlightPaint);

        canvas.drawCircle(kneePoint, 7.0, jointGlowPaint);
        canvas.drawCircle(kneePoint, 7.0, outlinePaint);
      }
    }

    highlightLeg(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    highlightLeg(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    PoseLandmark? targetKnee;
    if (leftKnee != null && rightKnee != null) {
      targetKnee = leftKnee.likelihood > rightKnee.likelihood ? leftKnee : rightKnee;
    } else {
      targetKnee = leftKnee ?? rightKnee;
    }

    if (targetKnee != null && targetKnee.likelihood > 0.45 && currentAngle > 0) {
      final kneePoint = translatePoint(targetKnee.x, targetKnee.y, size);
      _drawAngleBadge(canvas, kneePoint, currentAngle);
    }
  }

  void _drawAngleBadge(Canvas canvas, Offset position, double angle) {
    final bool isTargetReached = angle <= targetDepthThreshold;
    final textSpan = TextSpan(
      text: "${angle.toStringAsFixed(0)}°",
      style: TextStyle(
        color: isTargetReached ? const Color(0xFF00E676) : Colors.amberAccent,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.dx + 38, position.dy),
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      badgeRect,
      Paint()..color = Colors.black87,
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = isTargetReached ? const Color(0xFF00E676) : Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    textPainter.paint(
      canvas,
      Offset(badgeRect.left + 8, badgeRect.top + 4),
    );
  }
}