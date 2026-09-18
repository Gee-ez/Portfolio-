import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../core/database/db_helper.dart';
import '../engine/exercise_engine.dart';
import '../engine/squat_engine.dart';
import '../engine/pushup_engine.dart';
import 'camera_screen.dart';
import 'history_screen.dart';

// โมเดลสำหรับแสดงผลเมนูหน้าแรก
class ExerciseMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final ExerciseEngine Function() createEngine;

  ExerciseMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.createEngine,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraDescription? _camera;
  int _totalWorkouts = 0;
  int _totalReps = 0;
  int _avgAccuracy = 0;
  bool _isLoading = true;

  // รายการท่าออกกำลังกายทั้งหมด (เพิ่มท่าใหม่ได้ที่นี่ทันทีในบรรทัดเดียว)
  final List<ExerciseMenuItem> _exercises = [
    ExerciseMenuItem(
      title: "Squat Tracking",
      subtitle: "Knee angle & depth tracking",
      icon: Icons.accessibility_new_rounded,
      themeColor: Colors.cyanAccent,
      createEngine: () => SquatEngine(),
    ),
    ExerciseMenuItem(
      title: "Push-up Tracking",
      subtitle: "Full biomechanics (Arm, Trunk, Leg, Neck)",
      icon: Icons.fitness_center_rounded,
      themeColor: Colors.orangeAccent,
      createEngine: () => PushupEngine(),
    ),
    // ในอนาคตเมื่อมีท่าใหม่ เช่น Lunge หรือ Plank แค่เพิ่มตรงนี้:
    // ExerciseMenuItem(
    //   title: "Lunge Tracking",
    //   subtitle: "Dual knee flexion tracking",
    //   icon: Icons.directions_walk_rounded,
    //   themeColor: Colors.purpleAccent,
    //   createEngine: () => LungeEngine(),
    // ),
  ];

  @override
  void initState() {
    super.initState();
    _initAppResources();
  }

  Future<void> _initAppResources() async {
    await Future.wait([
      _loadDashboardStats(),
      _initCamera(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      }
    } catch (e) {
      debugPrint("Camera init warning: $e");
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final records = await DBHelper.instance.getAllWorkouts();
      if (records.isEmpty) {
        _totalWorkouts = 0;
        _totalReps = 0;
        _avgAccuracy = 0;
        return;
      }

      int sumTotal = 0;
      int sumCorrect = 0;

      for (final r in records) {
        sumTotal += r.totalReps;
        sumCorrect += r.correctReps;
      }

      _totalWorkouts = records.length;
      _totalReps = sumTotal;
      _avgAccuracy = sumTotal > 0 ? ((sumCorrect / sumTotal) * 100).toInt() : 0;
    } catch (e) {
      debugPrint("Database load warning: $e");
    }
  }

  void _startWorkout(ExerciseEngine engine) {
    if (_camera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กำลังเตรียมกล้อง กรุณาลองใหม่อีกครั้ง...")),
      );
      _initCamera();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          camera: _camera!,
          engine: engine,
        ),
      ),
    ).then((_) => _loadDashboardStats().then((_) => setState(() {})));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "AI Fitness Tracker",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.cyanAccent),
            tooltip: "Workout History",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
              _loadDashboardStats().then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const Text(
                          "Welcome Back!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Track your form and beat your personal best.",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        // Dashboard Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyanAccent.shade700.withOpacity(0.2),
                                const Color(0xFF1E1E1E),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem("Sessions", "$_totalWorkouts", Colors.white),
                              Container(height: 36, width: 1, color: Colors.white12),
                              _buildStatItem("Total Reps", "$_totalReps", Colors.cyanAccent),
                              Container(height: 36, width: 1, color: Colors.white12),
                              _buildStatItem("Avg Accuracy", "$_avgAccuracy%", Colors.greenAccent),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "Select Workout",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ]),
                    ),
                  ),
                  // รายการเมนูท่าที่เลื่อนดูได้แบบไดนามิก ปลอดภัยต่อการเพิ่ม 10+ ท่า
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _exercises[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildExerciseCard(item),
                          );
                        },
                        childCount: _exercises.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseMenuItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _startWorkout(item.createEngine()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.themeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.themeColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}