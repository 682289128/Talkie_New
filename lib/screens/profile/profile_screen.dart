import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkie_new/services/user_service.dart';
import 'package:talkie_new/screens/profile/edit_screen.dart';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String cloudName = "dfq7f9lcz";
  static const String uploadPreset = "talkie_upload";

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? imageUrl;
  File? _image;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // =============================
  // 📥 FETCH USER DATA
  // =============================
  Future<void> fetchUserData() async {
    final user = _auth.currentUser;

    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        setState(() {
          nameController.text = doc.data()?['name'] ?? '';
          phoneController.text = doc.data()?['phone'] ?? '';
          imageUrl = doc.data()?['image'] ?? '';
          isLoading = false;
        });
      } else {
        // 👇 IMPORTANT FIX
        setState(() {
          isLoading = false;
        });
      }
    } else {
      // 👇 ALSO IMPORTANT
      setState(() {
        isLoading = false;
      });
    }
  }

  // =============================
  // ☁️ UPLOAD IMAGE
  // =============================
  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo),
                title: Text("Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);

                  if (picked != null) {
                    setState(() {
                      _image = File(picked.path);
                    });
                    uploadImage();
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("Camera"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.camera);

                  if (picked != null) {
                    setState(() {
                      _image = File(picked.path);
                    });
                    await uploadImage();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> uploadImage() async {
    final user = _auth.currentUser;

    if (user == null || _image == null) return;

    try {
      final url =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath("file", _image!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();

        final imageUrl =
            RegExp(r'"secure_url":"(.*?)"').firstMatch(responseData)?.group(1);

        if (imageUrl != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'image': imageUrl,
          }, SetOptions(merge: true));

          setState(() {
            this.imageUrl = imageUrl;
          });

          await _userService.saveUser(
            nameController.text,
            user.email ?? "",
            phoneController.text,
            imageUrl
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Profile image updated")),
          );
        }
      } else {
        print("Upload failed");
      }
    } catch (e) {
      print("UPLOAD ERROR: $e");
    }
  }

  // =============================
  // 💾 UPDATE PROFILE
  // =============================
  Future<void> updateProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Profile updated successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("My Profile"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFFA855F7)],
                ),
              ),
              child: Column(
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundImage:
                            (imageUrl != null && imageUrl!.isNotEmpty)
                                ? NetworkImage(imageUrl!)
                                : null,
                        child: (imageUrl == null || imageUrl!.isEmpty)
                            ? Icon(Icons.person, size: 70)
                            : null,
                      ),
                      SizedBox(height: 8),

                      // 👇 EDIT BUTTON
                      GestureDetector(
                        onTap: pickImage,
                        child: Text(
                          "Edit",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 👇 NAME
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Name"),
              subtitle: Text(nameController.text.isNotEmpty
                  ? nameController.text
                  : "No name set"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditFieldScreen(
                      title: "Name",
                      field: "name",
                      initialValue: nameController.text,
                    ),
                  ),
                ).then((_) => fetchUserData());
              },
            ),

            Divider(),

            // 👇 PHONE
            ListTile(
              leading: Icon(Icons.phone),
              title: Text("Phone"),
              subtitle: Text(phoneController.text.isNotEmpty
                  ? phoneController.text
                  : "No phone set"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditFieldScreen(
                      title: "Phone",
                      field: "phone",
                      initialValue: phoneController.text,
                    ),
                  ),
                ).then((_) => fetchUserData());
              },
            ),

            Divider(),

            // 👇 EMAIL
            ListTile(
              leading: Icon(Icons.email),
              title: Text("Email"),
              subtitle: Text(_auth.currentUser?.email ?? "No email"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditFieldScreen(
                      title: "Email",
                      field: "email",
                      initialValue: _auth.currentUser?.email ?? "",
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
