import 'package:cloud_firestore/cloud_firestore.dart';


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
  }) async {
    final chatId = getChatId(senderId, receiverId);

    final now = DateTime.now();

    final messageData = {
      "text": text,
      "senderId": senderId,
      "receiverId": receiverId,
      "createdAt": FieldValue.serverTimestamp(),
      "localTime": "${now.hour}:${now.minute}",
      "status": "sent",
      "seen": false,
      "replyTo": replyTo,
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

  Future<void> deleteMessage(DocumentReference ref) async {
    await ref.delete();
  }
}