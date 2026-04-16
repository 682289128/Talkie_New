import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class AddContact extends StatefulWidget {
  const AddContact({Key? key}) : super(key: key);

  @override
  State<AddContact> createState() => _AddContactState();
}

class _AddContactState extends State<AddContact> {
  bool? isOnTalkie; // null = no check yet
  String? matchedUserId;
  bool isChecking = false;
  bool isSaving = false;
  String? inviteLink = "https://talkie.app/invite"; // placeholder
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _secondNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String normalizePhone(String number) {
    number = number.replaceAll(RegExp(r'\D'), '');

    if (number.startsWith('0')) {
      number = number.substring(1);
    }

    if (number.startsWith('237')) {
      number = number.substring(3);
    }

    if (number.length > 9) {
      number = number.substring(number.length - 9);
    }

    return number;
  }

  @override
  void initState() {
    super.initState();

    _phoneController.addListener(_checkIfUserExists);
  }

  Future<void> _checkIfUserExists() async {
    final phone = _phoneController.text.trim();

    if (phone.length < 9) {
      setState(() {
        isOnTalkie = null;
        matchedUserId = null;
      });
      return;
    }

    final fullPhone = "$_selectedCountryCode$phone";
    final normalizedPhone = normalizePhone(fullPhone);

    setState(() {
      isChecking = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection("users").get();

      bool exists = false;
      String? foundUserId;

      for (var doc in snapshot.docs) {
        final dbPhone = normalizePhone(doc["phone"] ?? "");

        if (dbPhone == normalizedPhone) {
          exists = true;
          foundUserId = doc.id;
          break;
        }
      }

      setState(() {
        isOnTalkie = exists;
        matchedUserId = foundUserId;
        isChecking = false;
      });
    } catch (e) {
      setState(() {
        isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _secondNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _selectedCountryCode = "+237";
  final _formKey = GlobalKey<FormState>();

  Future<void> saveContact({
    required String firstName,
    required String secondName,
    required String phone,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fullName = "$firstName $secondName";
      final fullPhone = "$_selectedCountryCode$phone";
      final normalizedPhone = normalizePhone(fullPhone);

      // 1. SAVE TO PHONE FIRST (FAST)
      await _saveToDeviceContacts(fullName, fullPhone);

      // 2. CHECK IF USER EXISTS
      final exists = matchedUserId != null;

      if (exists) {
        final id = matchedUserId!;

        // 3. SAVE DIRECTLY TO FIRESTORE CONTACTS
        await _saveTalkieContact(
          ownerId: user.uid,
          name: fullName,
          phone: fullPhone,
          matchedUserId: id,
        );
      }
    } catch (e) {
      print("Error saving contact: $e");
    }
  }

  Future<void> _saveTalkieContact({
    required String ownerId,
    required String name,
    required String phone,
    required String matchedUserId,
  }) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(ownerId)
        .collection("contacts")
        .doc(matchedUserId)
        .set({
      "name": name,
      "phone": phone,
      "userId": matchedUserId,
      "addedAt": FieldValue.serverTimestamp(),
    });
  }

  void _inviteUser() {
    final phone = _phoneController.text.trim();
    final fullPhone = "$_selectedCountryCode$phone";
    final normalizedPhone = normalizePhone(fullPhone);

    final message =
        "Hey 👋 I'm inviting you to join Talkie! Download here: $inviteLink";

    // You can later replace with real sharing logic
    print("Send invite to: $fullPhone");
    print("Message: $message");
  }

  Future<void> _saveToDeviceContacts(String name, String phone) async {
    var permission = await Permission.contacts.request();

    if (permission.isGranted) {
      final contact = Contact()
        ..displayName = name
        ..phones = [Phone(phone)];

      await FlutterContacts.insertContact(contact);
    } else {
      print("Contacts permission denied");
    }
  }

  Future<void> _syncContactsToFirebase(String userId) async {
    try {
      if (!await FlutterContacts.requestPermission()) return;

      // ✅ 1. Get ALL Talkie users ONCE
      final usersSnapshot =
          await FirebaseFirestore.instance.collection("users").get();

      // Create a map for fast lookup
      final Map<String, dynamic> talkieUsersMap = {};

      for (var doc in usersSnapshot.docs) {
        final phone = doc["phone"];
        if (phone != null) {
          talkieUsersMap[phone] = doc.id;
        }
      }

      // ✅ 2. Get phone contacts
      final contacts = await FlutterContacts.getContacts(withProperties: true);

      for (var contact in contacts) {
        if (contact.phones.isEmpty) continue;

        for (var phone in contact.phones) {
          final phoneNumber = phone.number.replaceAll(" ", "");

          // ✅ 3. Check locally (VERY FAST)
          if (talkieUsersMap.containsKey(phoneNumber)) {
            final matchedUserId = talkieUsersMap[phoneNumber];

            await FirebaseFirestore.instance
                .collection("users")
                .doc(userId)
                .collection("contacts")
                .doc(matchedUserId)
                .set({
              "name": contact.displayName,
              "phone": phoneNumber,
              "userId": matchedUserId,
              "addedAt": FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print("Sync Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Contact",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),

        // Gradient AppBar
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0XFF2563EB), // Talkie Blue
                Color(0XFF9333EA), // Talkie Purple
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            ListTile(
              title: Text(
                "Add New Contact on Talkie",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),

            /// FIRST NAME
            ListTile(
              title: Row(
                children: [
                  Icon(Icons.person_2),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        labelText: "First Name",
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Color.fromARGB(221, 87, 87, 87),
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFF2563EB)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Field required!";
                        }
                        if (value.trim().length < 2) {
                          return "Name must contain at least 2 characters";
                        }

                        if (!RegExp(r"^[a-zA-Z ]+$").hasMatch(value.trim())) {
                          return "Invalid Name";
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            /// SECOND NAME
            ListTile(
              title: Container(
                margin: EdgeInsets.only(left: 33),
                child: TextFormField(
                  controller: _secondNameController,
                  keyboardType: TextInputType.name,
                  decoration: InputDecoration(
                    labelText: "Second Name",
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: Color.fromARGB(221, 87, 87, 87),
                      ),
                    ),
                    floatingLabelStyle: TextStyle(color: Color(0xFF2563EB)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }

                    if (value.trim().length < 2) {
                      return "Name must contain at least 2 characters";
                    }

                    if (!RegExp(r"^[a-zA-Z ]+$").hasMatch(value.trim())) {
                      return "Invalid Name";
                    }

                    return null;
                  },
                ),
              ),
            ),

            ListTile(
              title: Row(
                children: [
                  Icon(Icons.phone_android),
                  SizedBox(
                    width: 10,
                  ),

                  /// COUNTRY CODE
                  Container(
                    height: 56, // 👈 matches TextFormField default height
                    width: 100,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Color.fromARGB(221, 87, 87, 87)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      underline: SizedBox(),
                      isDense: true,
                      items: [
                        DropdownMenuItem(
                            value: "+237", child: Text("+237 🇨🇲")),
                        DropdownMenuItem(value: "+1", child: Text("+1 🇺🇸")),
                        DropdownMenuItem(value: "+44", child: Text("+44 🇬🇧")),
                        DropdownMenuItem(value: "+33", child: Text("+33 🇫🇷")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCountryCode = value!;
                        });

                        _checkIfUserExists(); // 🔥 re-check when country changes
                      },
                    ),
                  ),

                  SizedBox(width: 8),

                  /// PHONE FIELD (IMPORTANT FIX HERE)
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Enter Phone",
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Color.fromARGB(221, 87, 87, 87),
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFF2563EB)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Phone number required";
                        }

                        if (!RegExp(r'^[0-9]{8,15}$').hasMatch(value.trim())) {
                          return "Invalid phone number";
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (isChecking)
              Padding(
                padding: const EdgeInsets.only(left: 160, top: 4),
                child: Text(
                  "Checking...",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),

            if (isOnTalkie != null && !isChecking)
              Padding(
                padding: const EdgeInsets.only(left: 155, top: 4),
                child: Text(
                  isOnTalkie!
                      ? "✔ Number found On Talkie"
                      : "✖ Number not found on Talkie",
                  style: TextStyle(
                    color: isOnTalkie! ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            SizedBox(height: 16),

            /// SAVE BUTTON
            Container(
                margin: EdgeInsets.only(left: 16, right: 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                    backgroundColor: Color(0xFF2563EB),
                  ),
                  onPressed: isSaving
                      ? null // disable button while saving
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              isSaving = true;
                            });

                            await saveContact(
                              firstName: _firstNameController.text.trim(),
                              secondName: _secondNameController.text.trim(),
                              phone: _phoneController.text.trim(),
                            );

                            setState(() {
                              isSaving = false;
                            });
                            if (isOnTalkie == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Contact Saved",
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  action: SnackBarAction(
                                    label: "  Start Chatting  ",
                                    textColor: Colors.yellow.withOpacity(0.9),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  backgroundColor:
                                      Color.fromARGB(255, 51, 137, 223),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Contact Saved (not on Talkie)",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  action: SnackBarAction(
                                    label: "  Invite  ",
                                    textColor: Colors.yellow.withOpacity(0.9),
                                    onPressed: () {
                                      _inviteUser();
                                    },
                                  ),
                                  backgroundColor:
                                      Color.fromARGB(255, 51, 137, 223),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          "Save",
                          style: TextStyle(color: Colors.white),
                        ),
                )),
          ],
        ),
      ),
    );
  }
}
