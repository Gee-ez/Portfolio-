import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/db_helper.dart';
import '../models/workout_record.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<WorkoutRecord>> _workoutRecords;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _workoutRecords = DBHelper.instance.getAllWorkouts();
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$remainingSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Workout History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<WorkoutRecord>>(
        future: _workoutRecords,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีประวัติการออกกำลังกาย",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final records = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final item = records[index];
              // แก้ไข: ใช้ item.timestamp ให้ตรงกับ Model
              final dateFormatted = DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp);
              final accuracy = item.totalReps > 0
                  ? ((item.correctReps / item.totalReps) * 100).toInt()
                  : 0;

              return Dismissible(
                key: Key(item.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  if (item.id != null) {
                    await DBHelper.instance.deleteWorkout(item.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("ลบรายการเรียบร้อย")),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.exerciseName == "Push-up"
                                  ? Colors.orangeAccent.withOpacity(0.2)
                                  : Colors.cyanAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.exerciseName.toUpperCase(),
                              style: TextStyle(
                                color: item.exerciseName == "Push-up"
                                    ? Colors.orangeAccent
                                    : Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            dateFormatted,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailItem("TOTAL", "${item.totalReps}", Colors.white),
                          _buildDetailItem("CORRECT", "${item.correctReps}", Colors.greenAccent),
                          _buildDetailItem("FIX", "${item.incorrectReps}", Colors.orangeAccent),
                          _buildDetailItem("ACCURACY", "$accuracy%", Colors.cyanAccent),
                          _buildDetailItem("TIME", _formatDuration(item.durationSeconds), Colors.white70),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}