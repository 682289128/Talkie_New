import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkie_new/screens/chats/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/services/contact_syn_service.dart';
import 'package:talkie_new/database/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class ContactPermissionScreen extends StatefulWidget {
  final bool fromLogin;
  const ContactPermissionScreen({super.key, this.fromLogin = false});

  @override
  State<ContactPermissionScreen> createState() =>
      _ContactPermissionScreenState();
}

class _ContactPermissionScreenState extends State<ContactPermissionScreen> {
  bool _isLoading = false;
  bool _isChecking = false;
  int _totalContacts = 0;
  int _processedContacts = 0;

  String _syncStatus = "Reading contacts...";
  @override
  void initState() {
    super.initState();

    // 🔥 AUTO RUN ONLY DURING LOGIN
    if (widget.fromLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestPermission(context);
      });
    }
  }

  Future<void> requestPermission(BuildContext context) async {
    var status = await Permission.contacts.status;

    // 🔥 LOGIN FLOW (NO UI)
    if (widget.fromLogin) {
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (!status.isGranted) {
        // ❌ don't stay on this screen → go to chat
        if (!context.mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Chat()),
        );
        return;
      }

      // ✅ permission granted → sync immediately
      List<Contact> contacts =
          await FlutterContacts.getContacts(withProperties: true);
      await saveContactsWithTalkieFlag(contacts);
      setState(() {
        _totalContacts = contacts.length;
        _processedContacts = 0;
      });

      List<String> phoneNumbers = [];

      for (var contact in contacts) {
        for (var phone in contact.phones) {
          phoneNumbers.add(normalizePhone(phone.number));
        }

        if (mounted) {
          setState(() {
            _processedContacts++;
          });
        }
      }
      setState(() {
        _isChecking = true;
        _syncStatus = "Checking contacts...";
        _processedContacts = 0;
      });

      await matchContacts(phoneNumbers, context);
    }

    // 🔵 REGISTRATION FLOW (KEEP YOUR UI)
    print("INITIAL STATUS: $status");

    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }

    print("AFTER REQUEST: $status");

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Contacts permission denied"),
          action: SnackBarAction(
            label: "Settings",
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    print("🔥 PERMISSION GRANTED");

    // NOW SAFE TO READ CONTACTS
    List<Contact> contacts =
        await FlutterContacts.getContacts(withProperties: true);
    await saveContactsWithTalkieFlag(contacts);

    setState(() {
      _totalContacts = contacts.length;
      _processedContacts = 0;
    });

    List<String> phoneNumbers = [];

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        phoneNumbers.add(normalizePhone(phone.number));
      }

      if (mounted) {
        setState(() {
          _processedContacts++;
        });
      }

      // Makes the animation visible
      await Future.delayed(const Duration(milliseconds: 8));
    }

    await matchContacts(phoneNumbers, context);
  }

  String normalizePhone(String number) {
    // REMOVE everything except digits
    number = number.replaceAll(RegExp(r'\D'), '');

    // remove leading zero
    if (number.startsWith('0')) {
      number = number.substring(1);
    }

    // remove country code 237
    if (number.startsWith('237')) {
      number = number.substring(3);
    }

    // keep last 9 digits
    if (number.length > 9) {
      number = number.substring(number.length - 9);
    }

    return number;
  }

  Future<void> matchContacts(List<String> numbers, BuildContext context) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final snapshot = await usersRef.get();

    if (mounted) {
      setState(() {
        _syncStatus = "Checking contacts...";
        _processedContacts = 0;
      });
    }

    List matchedUsers = [];
    List<QueryDocumentSnapshot> matchedDocs = [];

    for (var doc in snapshot.docs) {
      final userData = doc.data();

      String dbPhone = normalizePhone(userData['phone']?.toString() ?? '');

      if (numbers.contains(dbPhone)) {
        print("✅ MATCH FOUND: $dbPhone");

        matchedUsers.add(userData);
        matchedDocs.add(doc);
      }

      if (mounted) {
        setState(() {
          _processedContacts++;
        });
      }

      await Future.delayed(const Duration(milliseconds: 3));
    }
    print("CONTACTS: $numbers");
    print("MATCHED USERS: $matchedUsers");
    print("📊 MATCHED DOCS COUNT: ${matchedDocs.length}");

    if (matchedDocs.isEmpty) {
      print("⚠️ WARNING: No matched contacts found — nothing to save");
    }
    // 🔥 NEW: SAVE RELATIONSHIPS IN FIRESTORE
    try {
      await saveMatchedContactsToFirestore(matchedDocs);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final db = await DBHelper(user.uid).database;

        for (var doc in matchedDocs) {
          final data = doc.data() as Map<String, dynamic>;

          // 🔥 UPDATE EXISTING CONTACT INSTEAD OF ONLY INSERT
          await db.update(
            "contacts",
            {
              "userId": doc.id,
              "name": data["name"] ?? "",
              "phone": data["phone"] ?? "",
              "imagePath": null,
              "isOnTalkie": 1,
            },
            where: "phone = ?",
            whereArgs: [normalizePhone(data["phone"] ?? "")],
          );
          final updated = await db.update(
            "contacts",
            {
              "userId": doc.id,
              "isOnTalkie": 1,
            },
            where: "phone=?",
            whereArgs: [normalizePhone(data["phone"] ?? "")],
          );

          print(
              "Updated ${normalizePhone(data["phone"] ?? "")} -> $updated row(s)");
        }
      }
      if (mounted) {
        setState(() {
          _syncStatus = "Saving contacts...";
        });
      }
      // 🔥 Refresh SQLite with the newly uploaded Talkie contacts
      await ContactSyncService().syncContacts();
      if (mounted) {
        setState(() {
          _syncStatus = "Finishing...";
        });
      }
    } catch (e) {
      print("❌ ERROR CALLING SAVE FUNCTION: $e");
    }

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Chat(),
      ),
    );
  }

  Future<void> saveContactsWithTalkieFlag(List<Contact> contacts) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = await DBHelper(user.uid).database;

    for (var contact in contacts) {
      final phone = contact.phones.isNotEmpty
          ? normalizePhone(contact.phones.first.number)
          : "";

      await db.insert(
        "contacts",
        {
          "name": contact.displayName,
          "phone": phone,
          "imagePath": null,
          "isOnTalkie": 0, // default NOT on Talkie
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    print("📦 All contacts saved with isOnTalkie = 0");
  }

  void skip(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Chat()),
    );
  }

  Future<void> saveMatchedContactsToFirestore(
      List<QueryDocumentSnapshot> docs) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        print("❌ ERROR: User is NULL (not logged in)");
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in docs) {
        if (doc.id == currentUser.uid) continue;
        final contactData = doc.data() as Map<String, dynamic>;

        final contactRef = FirebaseFirestore.instance
            .collection("users")
            .doc(currentUser.uid)
            .collection("contacts")
            .doc(doc.id);

        batch.set(contactRef, {
          "name": contactData["name"] ?? "",
          "phone": contactData["phone"] ?? "",
          "userId": doc.id,
          "addedAt": FieldValue.serverTimestamp(),
        });

        print("🟡 Preparing to save: ${doc.id}");
      }

      await batch.commit();

      print("✅ SUCCESS: Contacts saved to Firestore");
    } on FirebaseException catch (e) {
      print("🔥 FIREBASE ERROR:");
      print("Code: ${e.code}");
      print("Message: ${e.message}");
      print("Details: ${e.toString()}");
    } catch (e, stackTrace) {
      print("❌ UNKNOWN ERROR:");
      print(e.toString());
      print("STACK TRACE:");
      print(stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 HIDE UI COMPLETELY DURING LOGIN
    if (widget.fromLogin) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 🔵 NORMAL UI FOR REGISTRATION
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    size: 100,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Find your friends on Talkie",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Allow access to your contacts so you can instantly connect with people you already know.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });

                        await requestPermission(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Allow Access",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => skip(context),
                    child: const Text(
                      "Not now",
                      style: TextStyle(color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 300,
                      child: LinearProgressIndicator(
                        value: _totalContacts == 0
                            ? null
                            : _processedContacts / _totalContacts,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(30),
                        color: const Color(0xFF2563EB),
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                    SizedBox(height: 20),
                    Column(
                      children: [
                        Text(
                          _syncStatus,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_isChecking)
                          Text(
                            "$_processedContacts / $_totalContacts",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        if (_isChecking)
                          Text(
                            "Checking contacts...",
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
