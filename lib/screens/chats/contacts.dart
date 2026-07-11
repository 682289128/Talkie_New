import 'package:flutter/material.dart';
import 'package:talkie_new/screens/chats/addContact_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/screens/chats/message_screen.dart';
import 'package:talkie_new/database/db_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';

class Contacts extends StatefulWidget {
  const Contacts({Key? key}) : super(key: key);

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  List<Map<String, dynamic>> contacts = [];
  String? hoveredContact;

  Future<void> loadContactsFromSQLite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = DBHelper(uid);
    final data = await db.database;

    final result = await data.query(
      'contacts',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    // 🔥 ADD THIS SAFETY CHECK (IMPORTANT)\

    print("⚠️ non_talkie_contacts table missing:");

    print("📦 SQLITE CONTACTS: $result");

    setState(() {
      contacts = result;
    });
  }

  Future<void> inviteViaWhatsApp(Map<String, dynamic> data) async {
    String phone = (data["phone"] ?? "").toString();

    // Remove spaces, +, -, ()
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    const talkieLink =
        "https://play.google.com/store/apps/details?id=com.yourcompany.talkie";

    final message = Uri.encodeComponent(
      "Hey! 👋\n\nI've been using Talkie and I think you'd really like it. It's a fast and simple way for us to chat and stay connected.\n\nDownload Talkie here:\n$talkieLink\n\nHope to see you there! 😊",
    );

    final uri = Uri.parse(
      "https://wa.me/$phone?text=$message",
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> inviteViaSMS(Map<String, dynamic> data) async {
    String phone = (data["phone"] ?? "").toString();

    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {
        'body':
            "Hey! 👋\n\nI've been using Talkie and I think you'd really like it. It's a fast and simple way for us to chat and stay connected\n\nhttps://play.google.com/store/apps/details?id=com.yourcompany.talkie",
      },
    );

    await launchUrl(
      smsUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> showInviteOptions(Map<String, dynamic> data) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
            child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            runSpacing: 4,
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  splashColor: Colors.green.withOpacity(0.15),
                  hoverColor: Colors.green.withOpacity(0.08),
                  leading: const Icon(
                    Icons.chat,
                    color: Colors.green,
                  ),
                  title: const Text("WhatsApp"),
                  onTap: () {
                    Navigator.pop(context);
                    inviteViaWhatsApp(data);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  splashColor: Colors.blue.withOpacity(0.15),
                  hoverColor: Colors.blue.withOpacity(0.08),
                  leading: const Icon(
                    Icons.sms,
                    color: Colors.blue,
                  ),
                  title: const Text("SMS"),
                  onTap: () {
                    Navigator.pop(context);
                    inviteViaSMS(data);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  splashColor: Colors.grey.withOpacity(0.15),
                  hoverColor: Colors.grey.withOpacity(0.08),
                  leading: const Icon(Icons.share),
                  title: const Text("More..."),
                  onTap: () {
                    Navigator.pop(context);
                    inviteContact(data);
                  },
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  Future<void> inviteContact(Map<String, dynamic> data) async {
    final name = data["name"] ?? "Friend";

    // Replace this with your Play Store/App Store link later
    const talkieLink =
        "https://play.google.com/store/apps/details?id=com.yourcompany.talkie";

    await Share.share(
      "Hi $name! 👋\n\n"
      "I'm using Talkie to chat and stay connected.\n\n"
      "Download it here:\n$talkieLink",
      subject: "Join me on Talkie",
    );
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase().trim();
      });
    });

    loadContactsFromSQLite(); // ONLY LOCAL DB
  }

  Future<void> initializeContacts() async {
    setState(() => _isLoading = true);

    try {
      await loadContactsFromSQLite();
      print("✅ Load from SQLite done");
    } catch (e) {
      print("❌ ERROR: $e");
    }

    setState(() => _isLoading = false);
  }

  TextSpan highlightText(String source, String query, {TextStyle? baseStyle}) {
    baseStyle ??= TextStyle(color: Colors.black87);

    if (query.isEmpty) {
      return TextSpan(text: source, style: baseStyle);
    }

    final lowerSource = source.toLowerCase();
    final lowerQuery = query.toLowerCase();

    List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      final index = lowerSource.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(
          text: source.substring(start),
          style: baseStyle,
        ));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: source.substring(start, index),
          style: baseStyle,
        ));
      }

      spans.add(TextSpan(
        text: source.substring(index, index + query.length),
        style: TextStyle(
            color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
      ));

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 Filter contacts by search text
    final filteredContacts = contacts.where((contact) {
      if (_searchText.isEmpty) return true;

      final name = (contact["name"] ?? "").toString().toLowerCase();
      final phone = (contact["phone"] ?? "").toString().toLowerCase();

      return name.contains(_searchText) || phone.contains(_searchText);
    }).toList();

// Split contacts
    final talkieContacts =
        filteredContacts.where((c) => (c["isOnTalkie"] ?? 0) == 1).toList();

    final nonTalkieContacts =
        filteredContacts.where((c) => (c["isOnTalkie"] ?? 0) == 0).toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0XFF2563EB), Color(0XFF9333EA)],
            ),
          ),
        ),
        titleSpacing: 0,
        title: _isSearching
            ? Container(
                height: 40,
                alignment: Alignment.center,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.white24,
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Contacts on Talkie",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Select contact and start chatting",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
        actions: [
          _isSearching
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    });
                  },
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 0, // ensures it takes only the space it needs
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      icon: Icon(Icons.search, size: 28, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSearching = true;
                        });
                      },
                    ),
                    SizedBox(width: 8),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        if (value == "add") {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddContact(),
                            ),
                          );

                          if (result == true) {
                            loadContactsFromSQLite(); // 🔥 refresh list
                          }
                        } else if (value == "invite") {
                          print("Invite clicked");
                        } else if (value == "settings") {
                          print("Settings clicked");
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: "add",
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_add,
                                size: 20,
                                color: const Color.fromARGB(255, 77, 77, 77),
                              ),
                              SizedBox(width: 10),
                              Text("Add Contact"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: "invite",
                          child: Row(
                            children: [
                              Icon(
                                Icons.share,
                                size: 20,
                                color: const Color.fromARGB(255, 77, 77, 77),
                              ),
                              SizedBox(width: 10),
                              Text("Invite Friends"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: "settings",
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings,
                                size: 20,
                                color: const Color.fromARGB(255, 77, 77, 77),
                              ),
                              SizedBox(width: 10),
                              Text("Settings"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 0),
                  ],
                ),
        ],
      ),
      body: Column(
        children: [
          // CONTACT COUNT TEXT (NOW FROM SQLITE ONLY)
          Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              "${talkieContacts.length} Contacts",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color.fromARGB(255, 39, 39, 39),
              ),
            ),
          ),

          // CONTACT LIST (ONLY SQLITE)

          Expanded(
            child: (_searchText.isEmpty
                    ? contacts.isEmpty
                    : talkieContacts.isEmpty && nonTalkieContacts.isEmpty)
                ? Center(
                    child: Text(
                      _searchText.isEmpty
                          ? "No contacts found"
                          : "No results for \"$_searchText\"",
                    ),
                  )
                : ListView(
                    children: [
                      // 🔵 TALKIE CONTACTS (TOP)
                      if (talkieContacts.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              color: Colors.white,
                              width: double.infinity,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  "Contacts on Talkie",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color.fromARGB(
                                        255, 105, 104, 104),
                                  ),
                                ),
                              ),
                            ),
                            for (final data in talkieContacts)
                              buildContactItem(
                                data,
                              )
                          ],
                        ),

                      // 🟠 NON TALKIE CONTACTS (BOTTOM)
                      if (nonTalkieContacts.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Text(
                                  "Invite to Talkie (${nonTalkieContacts.length} contacts)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color.fromARGB(
                                        255, 105, 104, 104),
                                  ),
                                ),
                              ),
                            ),
                            for (final data in nonTalkieContacts)
                              buildContactItem(data),
                          ],
                        ),
                    ],
                  ),
          )
        ],
      ),
    );
  }

  Widget buildContactItem(Map<String, dynamic> data) {
    final name = (data["name"] ?? "").toString();
    final phone = (data["phone"] ?? "").toString();
    final imagePath = (data["imagePath"] ?? "").toString();

    print("Building: $name");

    ImageProvider? imageProvider;
    try {
      if (imagePath.isNotEmpty) {
        imageProvider = FileImage(File(imagePath));
      }
    } catch (e) {
      imageProvider = null; // prevents crashes from bad file paths
    }

    String safeFirstLetter(String text) {
      try {
        if (text.trim().isEmpty) return "?";
        return String.fromCharCode(text.runes.first);
      } catch (e) {
        return "?";
      }
    }

    String safeText(String text) {
      try {
        return text;
      } catch (e) {
        return "";
      }
    }

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          hoveredContact = phone;
        });
      },
      onTapCancel: () {
        setState(() {
          hoveredContact = null;
        });
      },
      onTap: () async {
        await Future.delayed(Duration(milliseconds: 250));
        // Keep hover while action is happening
        if ((data["isOnTalkie"] ?? 0) == 1) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Message(
                contactName: name,
                contactUserId: data["userId"] ?? "",
                contactImage: imagePath,
              ),
            ),
          );
        } else {
          await showInviteOptions(data);
        }

        // Remove highlight only after action finishes
        if (mounted) {
          setState(() {
            hoveredContact = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hoveredContact == phone
              ? Colors.blue.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: hoveredContact == phone
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      safeFirstLetter(name),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: highlightText(
                      safeText(name),
                      _searchText,
                      baseStyle: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // 👇 Only show Invite button for non-Talkie contacts
            if ((data["isOnTalkie"] ?? 0) == 0)
              GestureDetector(
                onTap: () => showInviteOptions(data),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0XFF2563EB).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    "Invite",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
