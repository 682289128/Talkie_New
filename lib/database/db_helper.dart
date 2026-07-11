import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DBHelper {
  final String userId;

  DBHelper(this.userId);
  Database? _database;

  // GET DATABASE
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  // INIT DATABASE
  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'talkie_$userId.db');

    return await openDatabase(
      path,
      version: 3,
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
  phone TEXT UNIQUE,
  email TEXT,
  imagePath TEXT,
  imageUrl TEXT,
  isOnTalkie INTEGER DEFAULT 0
)
''');

        await db.execute('''
CREATE TABLE IF NOT EXISTS chats (
  id TEXT PRIMARY KEY,
  user1 TEXT,
  user2 TEXT,
  lastMessage TEXT,
  lastMessageTime INTEGER,
  status TEXT,
  lastSenderId TEXT
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
  replyToId TEXT,
  status TEXT,
  createdAt INTEGER,
  localTime TEXT,
  isDeleted INTEGER DEFAULT 0,
  edited INTEGER DEFAULT 0,
  restored INTEGER DEFAULT 0,
  deletedType TEXT,
  deletedAt INTEGER,
  deletedTime TEXT
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN replyTo TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN replyToId TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN status TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN localTime TEXT');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN isDeleted INTEGER DEFAULT 0');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN edited INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE messages ADD COLUMN deletedType TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN deletedAt INTEGER');
          await db.execute('ALTER TABLE messages ADD COLUMN deletedTime TEXT');
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

  Future<Map<String, dynamic>?> getContact(String userId) async {
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

  Future<Map<String, dynamic>?> getChatContact(String userId) async {
    return await getContactByUserId(userId);
  }

  Future<Map<String, dynamic>?> getContactByPhone(String phone) async {
    final dbClient = await database;

    final result = await dbClient.query(
      "contacts",
      where: "phone = ?",
      whereArgs: [phone],
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

  Future<bool> messageExists(String id) async {
    final db = await database;

    final result = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );

    return result.isNotEmpty;
  }

  //Chat Insert Method

  Future<void> insertOrUpdateChat(Map<String, dynamic> chat) async {
    final db = await database;

    await db.insert(
      'chats',
      chat,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  //chat Fetch Method
  Future<List<Map<String, dynamic>>> getChats(String userId) async {
    final db = await database;

    return await db.query(
      'chats',
      where: 'user1 = ? OR user2 = ?',
      whereArgs: [userId, userId],
      orderBy: 'lastMessageTime DESC',
    );
  }

  //get chat messages functions
  Future<List<Map<String, dynamic>>> getMessages(
      String userId, String contactId) async {
    final db = await database;

    return await db.query(
      'messages',
      where:
          '((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))',
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

  Future<void> updateMessageStatus(String id, String status) async {
    final db = await database;

    await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> printMessages() async {
    final db = await database;

    final messages = await db.query('messages');

    print("📦 ALL MESSAGES IN SQLITE:");

    for (var message in messages) {
      print(message);
    }
  }

  Stream<List<Map<String, dynamic>>> getMessagesStream(
    String userId,
    String contactId,
  ) {
    return FirebaseFirestore.instance
        .collection("messages")
        .where(
          Filter.or(
            Filter.and(
              Filter("senderId", isEqualTo: userId),
              Filter("receiverId", isEqualTo: contactId),
            ),
            Filter.and(
              Filter("senderId", isEqualTo: contactId),
              Filter("receiverId", isEqualTo: userId),
            ),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          "id": doc.id,
        };
      }).toList();
    });
  }

  Future<void> markMessageDeleted(
    String messageId,
    int isDeleted,
    String type,
  ) async {
    final db = await database;

    await db.update(
      "messages",
      {
        "isDeleted": isDeleted,
        "deletedType": type,
        "deletedAt": DateTime.now().millisecondsSinceEpoch,
        "deletedTime": DateFormat('hh:mm a').format(DateTime.now()),
      },
      where: "id = ?",
      whereArgs: [messageId],
    );
  }

  Future<String> getUserName(String userId) async {
    final db = await database;

    final result = await db.query(
      "users",
      where: "id = ?",
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first["name"]?.toString() ?? "Unknown";
    }

    return "Unknown";
  }

  Future<int> restoreMessage(String messageId) async {
    final db = await database;

    return await db.update(
      "messages",
      {
        "isDeleted": 0,
        "deletedType": null,
        "restored": 1,
      },
      where: "id = ?",
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessageForever(String messageId) async {
    final db = await database;

    return await db.delete(
      "messages",
      where: "id = ?",
      whereArgs: [messageId],
    );
  }

  Future<int> deleteLocalMessage(String messageId) async {
    final db = await database;

    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> printMessage(String messageId) async {
    final db = await database;

    final msg =
        await db.query('messages', where: 'id=?', whereArgs: [messageId]);

    print("");
    print("===== SQLITE MESSAGE =====");

    print(msg);

    print("==========================");
    print("");
  }
}
