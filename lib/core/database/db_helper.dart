import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/workout_record.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workout_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_name TEXT NOT NULL,
        total_reps INTEGER NOT NULL,
        correct_reps INTEGER NOT NULL,
        incorrect_reps INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE workouts ADD COLUMN exercise_name TEXT NOT NULL DEFAULT "Squat"');
    }
  }

  Future<int> insertWorkout(WorkoutRecord record) async {
    final db = await instance.database;
    return await db.insert('workouts', record.toMap());
  }

  Future<List<WorkoutRecord>> getAllWorkouts() async {
    final db = await instance.database;
    final result = await db.query('workouts', orderBy: 'timestamp DESC');
    return result.map((json) => WorkoutRecord.fromMap(json)).toList();
  }

  // เพิ่มฟังก์ชันลบรายการประวัติ
  Future<int> deleteWorkout(int id) async {
    final db = await instance.database;
    return await db.delete(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}