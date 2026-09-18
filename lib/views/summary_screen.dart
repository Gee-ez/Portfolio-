import 'package:flutter/material.dart';
import '../core/database/db_helper.dart';
import '../models/workout_record.dart';

class SummaryScreen extends StatefulWidget {
  final String exerciseName;
  final int total;
  final int correct;
  final int incorrect;
  final Duration duration;

  const SummaryScreen({
    super.key,
    required this.exerciseName,
    required this.total,
    required this.correct,
    required this.incorrect,
    required this.duration,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveRecord();
  }

  Future<void> _saveRecord() async {
    if (widget.total == 0) return;

    final record = WorkoutRecord(
      exerciseName: widget.exerciseName,
      totalReps: widget.total,
      correctReps: widget.correct,
      incorrectReps: widget.incorrect,
      durationSeconds: widget.duration.inSeconds,
      timestamp: DateTime.now(),
    );

    await DBHelper.instance.insertWorkout(record);
    if (mounted) {
      setState(() {
        _saved = true;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.total > 0
        ? ((widget.correct / widget.total) * 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Workout Summary", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                ),
                child: Text(
                  widget.exerciseName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Great Job!",
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _saved ? "บันทึกผลการออกกำลังกายแล้ว" : "การฝึกซ้อมเสร็จสิ้น",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCol("TOTAL REPS", "${widget.total}", Colors.white),
                        _buildStatCol("ACCURACY", "$accuracy%", Colors.cyanAccent),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCol("CORRECT", "${widget.correct}", Colors.greenAccent),
                        _buildStatCol("FIX REQUIRED", "${widget.incorrect}", Colors.orangeAccent),
                        _buildStatCol("TIME", _formatDuration(widget.duration), Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "DONE",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
