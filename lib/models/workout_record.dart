class WorkoutRecord {
  final int? id;
  final String exerciseName;
  final int totalReps;
  final int correctReps;
  final int incorrectReps;
  final int durationSeconds;
  final DateTime timestamp;

  WorkoutRecord({
    this.id,
    required this.exerciseName,
    required this.totalReps,
    required this.correctReps,
    required this.incorrectReps,
    required this.durationSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_name': exerciseName,
      'total_reps': totalReps,
      'correct_reps': correctReps,
      'incorrect_reps': incorrectReps,
      'duration_seconds': durationSeconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WorkoutRecord.fromMap(Map<String, dynamic> map) {
    return WorkoutRecord(
      id: map['id'] as int?,
      exerciseName: (map['exercise_name'] as String?) ?? "Squat",
      totalReps: map['total_reps'] as int,
      correctReps: map['correct_reps'] as int,
      incorrectReps: map['incorrect_reps'] as int,
      durationSeconds: map['duration_seconds'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}