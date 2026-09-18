import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class VectorMath {
  /// คำนวณมุม 3 มิติระหว่าง 3 ข้อต่อ โดยมี b เป็นจุดหมุน (Pivot)
  static double calculateAngle3D(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    // เวกเตอร์ BA
    final v1x = a.x - b.x;
    final v1y = a.y - b.y;
    final v1z = a.z - b.z;

    // เวกเตอร์ BC
    final v2x = c.x - b.x;
    final v2y = c.y - b.y;
    final v2z = c.z - b.z;

    // Dot Product: v1 • v2
    final dot = (v1x * v2x) + (v1y * v2y) + (v1z * v2z);

    // Magnitude: |v1| * |v2|
    final mag1 = math.sqrt((v1x * v1x) + (v1y * v1y) + (v1z * v1z));
    final mag2 = math.sqrt((v2x * v2x) + (v2y * v2y) + (v2z * v2z));

    if (mag1 * mag2 == 0) return 0.0;

    // คำนวณ cos(theta) พร้อม clamp ป้องกัน floating-point error
    var cosTheta = dot / (mag1 * mag2);
    cosTheta = cosTheta.clamp(-1.0, 1.0);

    // แปลงเรเดียนเป็นองศา
    return math.acos(cosTheta) * (180.0 / math.pi);
  }
}