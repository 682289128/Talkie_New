import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;

  // GET DATABASE
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  // INIT DATABASE
  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'talkie.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT UNIQUE,
            phone TEXT UNIQUE,
            imagePath TEXT
          )
        ''');
        await db.execute('''
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId TEXT UNIQUE,
  name TEXT,
  phone TEXT,
  email TEXT,
  imagePath TEXT,
  imageUrl TEXT
)
''');
        print("✅ Database and table created!");

        await db.execute('''
  CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    senderId TEXT,
    receiverId TEXT,
    text TEXT,
    replyTo TEXT,
    status TEXT,
    createdAt INTEGER,
    isDeleted INTEGER DEFAULT 0,
    edited INTEGER DEFAULT 0
  )
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('''
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      senderId TEXT,
      receiverId TEXT,
      text TEXT,
      replyTo TEXT,
      status TEXT,
      createdAt INTEGER
    )
  ''');
        }
        print("♻️ Database upgraded");
      },
    );
  }

  Future<Map<String, dynamic>?> getContactByUserId(String userId) async {
    final dbClient = await database;

    final result = await dbClient.query(
      'contacts',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  // INSERT USER
  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;

    await db.insert(
      'users',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print("✅ User saved locally!");

    // 👇 IMPORTANT: print AFTER insert
    await printUsers();
  }

  // PRINT USERS
  Future<void> printUsers() async {
    final db = await database;
    final users = await db.query('users');

    print("📦 ALL USERS IN SQLITE:");
    for (var user in users) {
      print(user);
    }
  }

  Future<void> updateUser(String email, Map<String, dynamic> data) async {
    final db = await database;

    await db.update(
      'users',
      data,
      where: 'email = ?',
      whereArgs: [email],
    );

    print("🔄 User updated locally!");
  }

  Future<void> insertContact(Map<String, dynamic> contact) async {
    final db = await database;

    await db.insert(
      'contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print("📦 Contact cached locally");
  }

  Future<void> insertOrUpdateContact(Map<String, dynamic> contact) async {
    final dbClient = await database;

    await dbClient.insert(
      'contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace, // 🔥 key part
    );
  }

  //Insert Message Function
  Future<void> insertMessage(Map<String, dynamic> msg) async {
    final db = await database;

    await db.insert(
      'messages',
      msg,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  //get chat messages functions
  Future<List<Map<String, dynamic>>> getMessages(
      String userId, String contactId) async {
    final db = await database;

    return await db.query(
      'messages',
      where:
          '((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)) AND isDeleted = 0',
      whereArgs: [userId, contactId, contactId, userId],
      orderBy: 'createdAt ASC',
    );
  }

  //delete Message function
  Future<void> deleteMessage(String id) async {
    final db = await database;

    await db.update(
      'messages',
      {
        'isDeleted': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //edit message Function
  Future<void> updateMessage(String id, String newText) async {
    final db = await database;

    await db.update(
      'messages',
      {
        'text': newText,
        'edited': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
