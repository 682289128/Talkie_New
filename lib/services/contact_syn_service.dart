import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/db_helper.dart';
import '../services/user_service.dart';
import 'dart:async';

class ContactSyncService {
  final String uid;
  late final DBHelper db;

  ContactSyncService() : uid = FirebaseAuth.instance.currentUser!.uid {
    db = DBHelper(uid);
  }

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
      final contactUserId = data['userId']?.toString() ?? "";

      String localImagePath = "";
      String imageUrl = "";

      if (contactUserId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(contactUserId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          imageUrl = userData?['imageUrl'] ?? userData?['image'] ?? "";

          print("IMAGE URL FOR $contactUserId => $imageUrl");

          // Check local cache first
          final localContact = await db.getContact(contactUserId);

          if (localContact == null) {
            // First time this contact exists locally
            if (imageUrl.isNotEmpty) {
              localImagePath = await UserService().cacheImage(imageUrl);
            }
          } else {
            // Contact already exists locally

            if (localContact["imageUrl"] == imageUrl) {
              // Image hasn't changed
              localImagePath = localContact["imagePath"] ?? "";
            } else {
              // Image changed
              if (imageUrl.isNotEmpty) {
                localImagePath = await UserService().cacheImage(imageUrl);
              }
            }
          }
        }
      }

      // 🧠 UPSERT LOGIC (prevents duplicates)
      await db.insertOrUpdateContact({
        'userId': contactUserId,
        'name': data['name'] ?? "",
        'phone': data['phone'] ?? "",
        'email': data['email'] ?? "",
        'imagePath': localImagePath,
        'imageUrl': imageUrl,
        'isOnTalkie': 1,
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
