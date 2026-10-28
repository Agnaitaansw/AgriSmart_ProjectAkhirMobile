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
      version: 5,
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
        await _buatTabelGame(db);
      },
    
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion == 2) {
          await db.execute(
              'ALTER TABLE user_rewards ADD COLUMN last_watered_at TEXT');
        }
        if (oldVersion >= 2 && oldVersion < 4) {
          await db.execute('DROP TABLE IF EXISTS user_plants');
        }
        await _buatTabelGame(db);
        await _tambahKolomJikaBelum(db, 'blockchain_logs', 'tx_hash', 'TEXT');
      },
    );
  }

  Future<void> _buatTabelGame(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_plants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        plant_name TEXT NOT NULL,
        planted_at TEXT NOT NULL,
        watering_every_days INTEGER NOT NULL DEFAULT 1,
        harvest_days INTEGER NOT NULL DEFAULT 90,
        deleted INTEGER NOT NULL DEFAULT 0, -- 1 = dihapus user, menunggu dihapus di Supabase
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE (user_id, plant_name)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        total_coins INTEGER NOT NULL DEFAULT 0,
        total_waterings INTEGER NOT NULL DEFAULT 0,
        last_watered_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_watering_cans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        can_id INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE (user_id, can_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS blockchain_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action_type TEXT NOT NULL,
        points_amount INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        previous_hash TEXT NOT NULL,
        current_hash TEXT NOT NULL,
        tx_hash TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _tambahKolomJikaBelum(
      Database db, String tabel, String kolom, String tipe) async {
    final info = await db.rawQuery('PRAGMA table_info($tabel)');
    final ada = info.any((c) => c['name'] == kolom);
    if (!ada) await db.execute('ALTER TABLE $tabel ADD COLUMN $kolom $tipe');
  }

  Future<void> upsertUserFromCloud({
    required int id,
    required String name,
    required String username,
    required String email,
    required String passwordHash,
    required String salt,
    required String createdAt,
  }) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'id': id,
        'name': name,
        'username': username,
        'email': email.toLowerCase(),
        'password_hash': passwordHash,
        'salt': salt,
        'created_at': createdAt,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

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