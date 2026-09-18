import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise_stats.dart';

abstract class ExerciseEngine {
  String get exerciseName;
  String get incorrectFeedbackVoice; // เสียงพูดเตือนเมื่อทำผิด เช่น "ย่อลงอีกนิด" หรือ "ระวังตัวงอ"
  String get visibilityWarningText;   // ข้อความเตือนมุมกล้อง

  ExerciseStats processPose(Pose pose);
  void reset();

  // ส่งหน้าที่วาดเส้นเฉพาะท่าให้ Engine ตัวเองจัดการ
  void paintOverlay(
    Canvas canvas,
    Size size,
    Pose pose,
    double currentAngle,
    Offset Function(double x, double y, Size size) translatePoint,
  );
}