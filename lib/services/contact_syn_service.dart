import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/db_helper.dart';
import '../services/user_service.dart';
import 'dart:async';

class ContactSyncService {
  final DBHelper db = DBHelper();

  Future<void> syncContacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("contacts")
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final contactUserId = data['userId'];

      String localImagePath = "";

      if (contactUserId != null && contactUserId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(contactUserId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          final imageUrl = userData?['imageUrl'] ?? userData?['image'] ?? "";

          print("IMAGE URL FOR $contactUserId => $imageUrl");

          if (imageUrl.isNotEmpty) {
            localImagePath = await UserService().cacheImage(imageUrl);
            print("📸 cached: $localImagePath");
          } else {
            print("⚠️ NO IMAGE FOUND FOR USER: $contactUserId");
          }
        }
      }

      // 🧠 UPSERT LOGIC (prevents duplicates)
      await db.insertOrUpdateContact({
        'userId': contactUserId ?? "",
        'name': data['name'] ?? "",
        'phone': data['phone'] ?? "",
        'email': data['email'] ?? "",
        'imagePath': localImagePath,
      });
    }

    print("🔄 Background sync complete");
  }

  Timer? _timer;

  void startAutoSync() {
    // run immediately first time
    syncContacts();

    // then every 1 minute
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      syncContacts();
    });
  }

  void stopAutoSync() {
    _timer?.cancel();
  }
}
