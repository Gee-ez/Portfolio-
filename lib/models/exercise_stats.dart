enum ExerciseMovementState {
  neutral,
  moving,
  descending,
  bottom,
  ascending,
}

class ExerciseStats {
  final int totalReps;
  final int correctReps;
  final int incorrectReps;
  final double currentAngle;
  final bool isBodyInFrame;
  final ExerciseMovementState state;
  final String feedback;

  ExerciseStats({
    this.totalReps = 0,
    this.correctReps = 0,
    this.incorrectReps = 0,
    this.currentAngle = 0.0,
    this.isBodyInFrame = false,
    this.state = ExerciseMovementState.neutral, // ถ้าไม่ใส่ ให้เป็น neutral อัตโนมัติ
    this.feedback = "",                         // ถ้าไม่ใส่ ให้เป็นข้อความว่าง "" อัตโนมัติ
  });

  // Factory เริ่มต้นค่าเปล่า
  factory ExerciseStats.initial() {
    return ExerciseStats();
  }
}