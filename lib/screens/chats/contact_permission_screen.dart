import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkie_new/screens/chats/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactPermissionScreen extends StatefulWidget {
  final bool fromLogin;
  const ContactPermissionScreen({super.key, this.fromLogin = false});

  @override
  State<ContactPermissionScreen> createState() =>
      _ContactPermissionScreenState();
}

class _ContactPermissionScreenState extends State<ContactPermissionScreen> {
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

  void requestPermission(BuildContext context) async {
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

    List<String> phoneNumbers = [];

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        phoneNumbers.add(normalizePhone(phone.number));
      }
    }

    await matchContacts(phoneNumbers, context);
    return;
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

    List<String> phoneNumbers = [];

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        phoneNumbers.add(normalizePhone(phone.number));
      }
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ICON / LOGO
              const Icon(
                Icons.people_alt_rounded,
                size: 100,
                color: Color(0xFF2563EB),
              ),

              const SizedBox(height: 30),

              // TITLE
              const Text(
                "Find your friends on Talkie",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              // DESCRIPTION
              const Text(
                "Allow access to your contacts so you can instantly connect with people you already know.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 50),

              // ALLOW BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => requestPermission(context),
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

              // SKIP BUTTON
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
    );
  }
}
