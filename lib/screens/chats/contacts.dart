import 'package:flutter/material.dart';
import 'package:talkie_new/screens/chats/addContact_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/screens/chats/message_screen.dart';
import 'package:talkie_new/database/db_helper.dart';
import 'dart:io';
import 'dart:async';
import 'package:talkie_new/services/contact_syn_service.dart';

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

  Future<void> loadContactsFromSQLite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await DBHelper().database;

    final result = await data.query(
      'contacts',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    print("📦 SQLITE CONTACTS: $result");
    setState(() {
      contacts = result;
    });
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
                      onSelected: (value) {
                        if (value == "add") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddContact(),
                            ),
                          );
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
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              "${contacts.length} Contacts",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0XFF2563EB),
              ),
            ),
          ),

          // CONTACT LIST (ONLY SQLITE)
          Expanded(
            child: contacts.isEmpty
                ? Center(child: Text("No contacts found"))
                : Builder(
                    builder: (context) {
                      // FILTER SEARCH
                      final filteredContacts = contacts.where((c) {
                        final name = (c["name"] ?? "").toLowerCase();
                        final phone = (c["phone"] ?? "").toLowerCase();

                        return name.contains(_searchText) ||
                            phone.contains(_searchText);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final data = filteredContacts[index];

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Message(
                                    contactName: data["name"] ?? "",
                                    contactUserId: data["userId"] ?? "",
                                    contactImage: data["imagePath"] ?? "",
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage:
                                        (data["imagePath"] != null &&
                                                data["imagePath"]
                                                    .toString()
                                                    .isNotEmpty)
                                            ? FileImage(File(data["imagePath"]))
                                            : null,
                                    child: (data["imagePath"] == null ||
                                            data["imagePath"]
                                                .toString()
                                                .isEmpty)
                                        ? Text(
                                            data["name"] != null &&
                                                    data["name"].isNotEmpty
                                                ? data["name"][0]
                                                : "?",
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: highlightText(
                                          data["name"] ?? "",
                                          _searchText,
                                          baseStyle: TextStyle(
                                            color: const Color.fromARGB(
                                                255, 37, 37, 37),
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      RichText(
                                        text: highlightText(
                                          data["phone"] ?? "",
                                          _searchText,
                                          baseStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
