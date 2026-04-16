import 'package:flutter/material.dart';
import 'package:talkie_new/screens/chats/addContact_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/screens/chats/message_screen.dart';

class Contacts extends StatefulWidget {
  const Contacts({Key? key}) : super(key: key);

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase().trim();
      });
    });
  }

  Stream<QuerySnapshot> getContacts() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    return FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("contacts")
        .orderBy("addedAt", descending: true)
        .snapshots();
  }

  TextSpan highlightText(String source, String query) {
    if (query.isEmpty) {
      return TextSpan(text: source, style: TextStyle(color: Colors.black));
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
          style: TextStyle(color: Colors.black),
        ));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: source.substring(start, index),
          style: TextStyle(color: Colors.black),
        ));
      }

      spans.add(TextSpan(
        text: source.substring(index, index + query.length),
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
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
          // CONTACT COUNT TEXT
          Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: StreamBuilder<QuerySnapshot>(
              stream: getContacts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    "0 Contacts",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0XFF2563EB),
                    ),
                  );
                }

                final count = snapshot.data!.docs.length;

                return Text(
                  "$count Contacts",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFF2563EB),
                  ),
                );
              },
            ),
          ),

          // CONTACT LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getContacts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error loading contacts"));
                }

                final allDocs = snapshot.data!.docs;

                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final name = (data["name"] ?? "").toString().toLowerCase();
                  final phone = (data["phone"] ?? "").toString().toLowerCase();

                  final query = _searchText.toLowerCase();

                  return name.contains(query) || phone.contains(query);
                }).toList();

                if (docs.isEmpty) {
                  return Center(child: Text("No contacts found"));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Message(
                              contactName: (data["name"] ?? "").toString(),
                              contactUserId: (data["userId"] ?? "").toString(),
                              contactImage: (data["image"] ?? "").toString(),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              child: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(data["userId"])
                                    .get(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return CircularProgressIndicator(
                                        strokeWidth: 2);
                                  }

                                  if (snapshot.hasData &&
                                      snapshot.data!.exists) {
                                    final userData = snapshot.data!.data()
                                        as Map<String, dynamic>;

                                    final imageUrl = userData["image"];

                                    if (imageUrl != null &&
                                        imageUrl.isNotEmpty) {
                                      return ClipOval(
                                        child: Image.network(
                                          imageUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    }
                                  }

                                  // fallback to first letter
                                  return Text(
                                    data["name"] != null &&
                                            data["name"].isNotEmpty
                                        ? data["name"][0]
                                        : "?",
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: highlightText(
                                    data["name"] ?? "No Name",
                                    _searchText,
                                  ),
                                ),
                                Text(
                                  data["phone"] ?? "",
                                  style: TextStyle(color: Colors.grey),
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
          ),
        ],
      ),
    );
  }
}
