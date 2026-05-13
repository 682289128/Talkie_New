import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatService {
  final _firestore = FirebaseFirestore.instance;

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
    required String senderId,
    required String receiverId,
    required String text,
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

    final messageData = {
      "text": text,
      "senderId": senderId,
      "receiverId": receiverId,
      "senderName": senderName, // 👈 TEMP (replace later with real name)
      "createdAt": FieldValue.serverTimestamp(),
      "localTime": DateFormat('hh:mm a').format(now),
      "status": "sent",
      "seen": false,
      "replyTo": replyTo,
      "replyToId": replyToId,
    };

    await _firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add(messageData);

    await _firestore.collection("chats").doc(chatId).set({
      "participants": [senderId, receiverId],
      "lastMessage": text,
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMessage({
    required String messageId,
    required String newText,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final chatId = getChatId(senderId, receiverId); // ✅ correct

      await _firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "text": newText,
        "edited": 1,
      });

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

    final messagesRef =
        _firestore.collection("chats").doc(chatId).collection("messages");

    final messageRef = messagesRef.doc(messageId);
    

    // 🔴 DELETE LOGIC
if (type == "temporary") {
  await messageRef.update({
    "isDeleted": 1,
    "deletedType": "temporary",
    "deletedAt": FieldValue.serverTimestamp(),
    "deletedTime": DateFormat('hh:mm a').format(DateTime.now()),
  });
} else if (type == "permanent") {
  await messageRef.update({
    "isDeleted": 1,
    "deletedType": "permanent",
    "deletedAt": FieldValue.serverTimestamp(),
    "deletedTime": DateFormat('hh:mm a').format(DateTime.now()),
    "text": "",
  });
}

    // 🔥 GET THE REAL LAST MESSAGE (even if deleted)
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
    });

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


//call this when user recieves the message(delivered)
  Future<void> markAsDelivered({
  required String senderId,
  required String receiverId,
}) async {
  final chatId = getChatId(senderId, receiverId);

  final messagesRef = _firestore
      .collection("chats")
      .doc(chatId)
      .collection("messages");

  final query = await messagesRef
      .where("receiverId", isEqualTo: receiverId)
      .where("status", isEqualTo: "sent")
      .get();

  for (var doc in query.docs) {
    await doc.reference.update({
      "status": "delivered",
      "deliveredAt": FieldValue.serverTimestamp(),
    });
  }
}

//call this when user enters the chat(seen)
Future<void> markAsSeen({
  required String senderId,
  required String receiverId,
}) async {
  final chatId = getChatId(senderId, receiverId);

  final messagesRef = _firestore
      .collection("chats")
      .doc(chatId)
      .collection("messages");

  final query = await messagesRef
      .where("receiverId", isEqualTo: receiverId)
      .where("status", whereIn: ["sent", "delivered"])
      .get();

  for (var doc in query.docs) {
    await doc.reference.update({
      "status": "seen",
      "seen": true,
      "seenAt": FieldValue.serverTimestamp(),
    });
  }
}
}
