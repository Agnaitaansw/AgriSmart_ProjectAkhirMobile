import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';

/// Database lokal SQLite.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'agrismart.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  /// Cari berdasarkan email ATAU username (case-insensitive).
  Future<UserModel?> findByIdentifier(String identifier) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = ? OR LOWER(username) = ?',
      whereArgs: [identifier.toLowerCase(), identifier.toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<UserModel?> findById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<List<UserModel>> getUnsynced() async {
    final db = await database;
    final rows = await db.query('users', where: 'synced = 0');
    return rows.map(UserModel.fromMap).toList();
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    await db.update('users', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
