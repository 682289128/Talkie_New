import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

final DBHelper _dbHelper = DBHelper();

class ChatService {
  final _firestore = FirebaseFirestore.instance;
  final DBHelper _dbHelper = DBHelper();

  String getChatId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  Stream<QuerySnapshot> getMessages(String user1, String user2) {
    final chatId = getChatId(user1, user2);

    return _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("createdAt", descending: false)
        .snapshots();
  }

  Future<void> sendMessage({
    required String messageId,
    required String senderId,
    required String receiverId,
    required String text,
    String? initialStatus,
    String? replyTo,
    String? replyToId,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    final now = DateTime.now();

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(senderId)
        .get();

    final userData = userDoc.data();

    final senderName = (userData != null &&
            userData["name"] != null &&
            userData["name"].toString().trim().isNotEmpty)
        ? userData["name"]
        : "Unknown";

    final docRef = messageId != null
        ? _firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc(messageId)
        : _firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc();

    final realMessageId = docRef.id;
    final messageData = {
      "id": realMessageId,
      "text": text,
      "senderId": senderId,
      "receiverId": receiverId,
      "senderName": senderName, // 👈 TEMP (replace later with real name)
      "createdAt": FieldValue.serverTimestamp(),
      "localTime": DateFormat('hh:mm a').format(now),
      "status": initialStatus ?? "sent",
      "seen": false,
      "replyTo": replyTo,
      "replyToId": replyToId,
    };

    await docRef.set(messageData);


    await _dbHelper.insertMessage({
      "id": messageId,
      "senderId": senderId,
      "receiverId": receiverId,
      "text": text,
      "replyTo": replyTo,
      "replyToId": replyToId,
      "status": "sent",
      "createdAt": now.millisecondsSinceEpoch,
      "localTime": DateFormat('hh:mm a').format(now),
      "isDeleted": 0,
      "edited": 0
    });

    await _dbHelper.printMessages();

    await _firestore.collection("chats").doc(chatId).set({
      "participants": [senderId, receiverId],
      "lastMessage": text,
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveMessageLocally({
    required String messageId,
    required String senderId,
    required String receiverId,
    required String text,
    String? replyTo,
    String? replyToId,
  }) async {
    final now = DateTime.now();

    await _dbHelper.insertMessage({
      "id": messageId,
      "senderId": senderId,
      "receiverId": receiverId,
      "text": text,
      "replyTo": replyTo,
      "replyToId": replyToId,
      "status": "pending",
      "createdAt": now.millisecondsSinceEpoch,
      "localTime": DateFormat('hh:mm a').format(now),
      "isDeleted": 0,
      "edited": 0,
    });
  }

  Future<void> retryPendingMessages({
    required String senderId,
    required String receiverId,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    final snapshot = await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .where("senderId", isEqualTo: senderId)
        .where("status", isEqualTo: "pending")
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        "status": "sent",
      });
    }
  }

  Future<void> updateMessage({
    required String messageId,
    required String newText,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final chatId = getChatId(senderId, receiverId);

      // 1. FIRESTORE UPDATE
      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "text": newText,
        "edited": 1,
      });

      // 2. LOCAL SQLITE UPDATE (🔥 MISSING PART)
      await _dbHelper.updateMessage(messageId, newText);

      print("✅ Message updated successfully");
    } catch (e) {
      print("🔥 Firestore Update Error: $e");
    }
  }

  Future<void> deleteMessage({
    required String messageId,
    required String senderId,
    required String receiverId,
    required String type,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    final messageRef = _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId);

    final now = DateTime.now();

    if (type == "temporary") {
      await messageRef.update({
        "isDeleted": 1,
        "deletedType": "temporary",
        "deletedAt": FieldValue.serverTimestamp(),
        "deletedTime": DateFormat('hh:mm a').format(now),
      });

      await _dbHelper.markMessageDeleted(messageId, 1, "temporary");
    } else {
      await messageRef.update({
        "isDeleted": 1,
        "deletedType": "permanent",
        "deletedAt": FieldValue.serverTimestamp(),
        "deletedTime": DateFormat('hh:mm a').format(now),
        "text": "",
      });

      await _dbHelper.markMessageDeleted(messageId, 1, "permenent");
    }

    // update last message (keep your existing logic)
    final lastDoc = await messageRef.parent
        .orderBy("createdAt", descending: true)
        .limit(1)
        .get();

    String newLastMessage = "";
    Timestamp? newTime;

    if (lastDoc.docs.isNotEmpty) {
      final data = lastDoc.docs.first.data();
      final isDeleted = data["isDeleted"] == 1;

      newLastMessage = isDeleted ? "🗑️ Message deleted" : (data["text"] ?? "");

      newTime = data["createdAt"];
    }

    await _firestore.collection("chats").doc(chatId).set({
      "lastMessage": newLastMessage,
      "lastMessageTime": newTime ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> restoreMessage({
    required String messageId,
    required String senderId,
    required String receiverId,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    final messageRef = _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId);

    await messageRef.update({
      "isDeleted": 0,
      "deletedType": null,
      "deletedAt": null,
      "deletedTime": null,
      "restored": 1,
    });

// 🔥 RESTORE SQLITE TOO
    await _dbHelper.restoreMessage(messageId);

    // 🔥 OPTIONAL: update lastMessage if restored message is latest
    final messagesRef =
        _firestore.collection("chats").doc(chatId).collection("messages");

    final lastDoc =
        await messagesRef.orderBy("createdAt", descending: true).limit(1).get();

    String newLastMessage = "";
    Timestamp? newTime;

    if (lastDoc.docs.isNotEmpty) {
      final data = lastDoc.docs.first.data();

      final isDeleted = data["isDeleted"] == 1;

      if (isDeleted) {
        newLastMessage = "🗑️ Message deleted";
      } else {
        newLastMessage = data["text"] ?? "";
      }

      newTime = data["createdAt"];
    }

    await _firestore.collection("chats").doc(chatId).set({
      "lastMessage": newLastMessage,
      "lastMessageTime": newTime ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

// 🔥 MARK MESSAGES AS DELIVERED
  Future<void> markMessagesAsDelivered({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);

    final snapshot = await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .where("receiverId", isEqualTo: currentUserId)
        .where("status", isEqualTo: "sent")
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        "status": "delivered",
      });
    }
  }

// 🔥 MARK MESSAGES AS SEEN
  Future<void> markMessagesAsSeen({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);

    final snapshot = await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .where("receiverId", isEqualTo: currentUserId)
        .where("status", isEqualTo: "delivered")
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        "status": "seen",
        "seen": true,
        "seenAt": FieldValue.serverTimestamp(), // 🔥 ADD THIS
      });
    }
  }

//call this when user enters the chat(seen)
  Future<void> markAsSeen({
    required String senderId,
    required String receiverId,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    final messagesRef =
        _firestore.collection("chats").doc(chatId).collection("messages");

    final query = await messagesRef
        .where("receiverId", isEqualTo: receiverId)
        .where("status", whereIn: ["sent", "delivered"]).get();

    for (var doc in query.docs) {
      await doc.reference.update({
        "status": "seen",
        "seen": true,
        "seenAt": FieldValue.serverTimestamp(),
      });
    }
  }
}
