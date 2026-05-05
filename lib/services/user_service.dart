import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../database/db_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final DBHelper dbHelper = DBHelper();

  // 📸 Download + cache image locally
  Future<String> cacheImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      final dir = await getApplicationDocumentsDirectory();

      // safer unique filename
      final fileName =
          DateTime.now().millisecondsSinceEpoch.toString() + ".jpg";

      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes);

      return file.path;
    } catch (e) {
      print("❌ Image cache error: $e");
      return "";
    }
  }

  // 💾 SAVE USER AFTER SIGNUP
  Future<void> saveUser(
    String name,
    String email,
    String phone,
    String imageUrl,
  ) async {
    String localPath = "";

    // only cache if image exists
    if (imageUrl.isNotEmpty) {
      localPath = await cacheImage(imageUrl);
    }

    await dbHelper.insertUser({
      'name': name,
      'email': email,
      'phone': phone,
      'imagePath': localPath,
    });

    print("✅ User saved via UserService");
  }

  // 🔄 REAL-TIME SYNC FROM FIRESTORE
  void listenUser(String userId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) return;

      final data = doc.data()!;

      String name = data['name'] ?? "";
      String email = data['email'] ?? "";
      String phone = data['phone'] ?? "";
      String imageUrl = data['imageUrl'] ?? "";

      String localPath = "";

      if (imageUrl.isNotEmpty) {
        localPath = await cacheImage(imageUrl);
      }

      await dbHelper.updateUser(email, {
        'name': name,
        'email': email,
        'phone': phone,
        'imagePath': localPath,
      });

      print("🔄 User synced from Firestore → SQLite updated");
    });
  }
}
