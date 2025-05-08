import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pokemon_card.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cards.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // change version for schema changes
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        name TEXT,
        imageUrl TEXT,
        marketPrice REAL,
        priceChange REAL,
        setCode TEXT,
        cardNumber TEXT,
        lastMarketPrice REAL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE cards ADD COLUMN lastMarketPrice REAL');
    }
  }

  Future<List<CardData>> getCards() async {
    final db = await instance.database;
    final maps = await db.query('cards');
    return maps.map((json) => CardData.fromJson(json)).toList();
  }

  Future<int> insertCard(CardData card) async {
    final db = await instance.database;
    return await db.insert(
      'cards',
      card.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCard(CardData card) async {
    final db = await instance.database;
    return await db.update(
      'cards',
      card.toJson(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(String id) async {
    final db = await instance.database;
    return await db.delete(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}