import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/services/chat_service.dart';
import 'package:talkie_new/database/db_helper.dart';

class InitialSyncService {
  final DBHelper _dbHelper;

  InitialSyncService(String userId) : _dbHelper = DBHelper(userId);
  Future<void> clearLocalData() async {
    final db = await _dbHelper.database;

    await db.delete("messages");
    await db.delete("chats");
    await db.delete("contacts");

    print("🧹 LOCAL SQLITE CLEARED ON LOGIN");
  }

  Future<void> syncEverything() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

// Sync users

// Sync contacts

// Sync chats

// Sync messages

    final chatService = ChatService(uid);

    await chatService.syncMessages();

    print("Initial sync done");
  }
}
