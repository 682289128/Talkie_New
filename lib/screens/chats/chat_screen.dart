import 'package:flutter/material.dart';
import 'package:talkie_new/screens/chats/message_screen.dart';
import 'package:talkie_new/screens/chats/addContact_screen.dart';
import 'package:talkie_new/screens/chats/contacts.dart';
import 'package:talkie_new/screens/splash/splash_screen.dart';
import 'package:talkie_new/services/auth_service.dart';
import 'package:talkie_new/screens/profile/profile_screen.dart';
//import 'package:talkie_new/screens/chats/contact_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Chat extends StatefulWidget {
  const Chat({
    Key? key,
  }) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  String formatTime(dynamic timestamp) {
    if (timestamp == null) return "";

    DateTime dt;

    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return "";
    }

    final now = DateTime.now();

    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return "${dt.day}/${dt.month}/${dt.year}";
  }

  late Stream<QuerySnapshot> _chatListener;
  Future<List<String>> getChatUserIds() async {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final snapshot = await FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: currentUser.uid)
        .get();

    List<String> userIds = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      List participants = data["participants"] ?? [];

      for (var id in participants) {
        if (id != currentUser.uid) {
          userIds.add(id);
        }
      }
    }

    return userIds;
  }

  String safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  List get filteredUsers {
    if (_searchController.text.isEmpty) {
      return syncedUsers;
    }

    return syncedUsers.where((user) {
      final name = (user["name"] ?? "").toString().toLowerCase();
      final phone = (user["phone"] ?? "").toString().toLowerCase();
      final query = _searchController.text.toLowerCase();

      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  List syncedUsers = [];

  Stream<QuerySnapshot> chatStream() {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: currentUser.uid)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();

    final currentUser = FirebaseAuth.instance.currentUser!;

    _chatListener = FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: currentUser.uid)
        .snapshots();

    _chatListener.listen((snapshot) {
      loadChats(); // 🔥 updates syncedUsers automatically
    });

    loadChats(); // initial load
  }

  Future<void> loadChats() async {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final snapshot = await FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: currentUser.uid)
        .get();

    List<Map<String, dynamic>> chatUsers = [];

    for (var doc in snapshot.docs) {
      List participants = doc["participants"] ?? [];

      String? otherUserId;

      for (var id in participants) {
        if (id != currentUser.uid) {
          otherUserId = id.toString();
          break;
        }
      }

      if (otherUserId == null) continue;

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(otherUserId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        chatUsers.add({
          "userId": otherUserId,
          ...userDoc.data()!,
          "message": doc["lastMessage"] ?? "",
          "time": formatTime(doc["lastMessageTime"]), // ✅ format here
          "status": "seen",
        });
      }
    }

    setState(() {
      syncedUsers = chatUsers;
    });
  }

  bool _isSearching = false;
  bool isCardView = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final users = filteredUsers;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: "Search...",
                  border: InputBorder.none,
                ),
              )
            : Row(
                children: [
                  Image.asset("assets/images/logo.png", height: 40),
                  SizedBox(width: 8),
                  Image.asset("assets/images/logo_text.png", height: 18),
                ],
              ),
        actions: [
          _isSearching
              ? IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    });
                  },
                )
              : IconButton(
                  icon: Icon(Icons.search, size: 30),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
          SizedBox(width: 0),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.black87),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 6,
              onSelected: (value) {
                if (value == "profile") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                }

                if (value == "settings") {
                  // Settings page later
                }

                if (value == "logout") {
                  AuthService().logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => Welcome_Talkie()),
                    (route) => false,
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "profile",
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20, color: Colors.blue),
                      SizedBox(width: 10),
                      Text("Profile"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: "settings",
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20, color: Colors.grey),
                      SizedBox(width: 10),
                      Text("Settings"),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: "logout",
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final currentUser = FirebaseAuth.instance.currentUser!;
          final chats = snapshot.data!.docs;

final filtered = syncedUsers.where((user) {
  final name = (user["name"] ?? "").toLowerCase();
  final phone = (user["phone"] ?? "").toLowerCase();
  final query = _searchController.text.toLowerCase();

  return name.contains(query) || phone.contains(query);
}).toList();
          if (_searchController.text.isNotEmpty && filtered.isEmpty) {
            return Center(
              child: Text("No Contacts Found",
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }
          if (_searchController.text.isEmpty && filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 💬 BIG ICON WITH STYLE
                    Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF60A5FA),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),

                    SizedBox(height: 30),

                    // 🧠 TITLE
                    Text(
                      "No Conversations Yet",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),

                    SizedBox(height: 10),

                    // 📝 SUBTITLE
                    Text(
                      "Start a chat with your friends and\nyour messages will appear here.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 30),

                    // 🚀 CTA BUTTON
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Contacts()),
                        );
                      },
                      icon: Icon(Icons.add_comment_rounded),
                      label: Text("Start a Chat"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ✅ KEEP YOUR EXISTING UI BELOW (UNCHANGED)
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔵 ONLINE NOW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Online Now",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0XFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddContact(),
                                ),
                              );
                            },
                            icon: Icon(Icons.add_circle),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      SizedBox(
                        height: 95,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final user = filtered[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: user["image"] != null &&
                                            user["image"]
                                                .toString()
                                                .startsWith("http")
                                        ? NetworkImage(user["image"])
                                        : null,
                                    child: user["image"] == null
                                        ? Icon(Icons.person)
                                        : null,
                                  ),
                                  SizedBox(height: 6),
                                  highlightText(
                                    (user["name"] ?? "").toString().length > 10
                                        ? "${user["name"].toString().substring(0, 10)}..."
                                        : user["name"] ?? "",
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Chat List",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0XFF2563EB),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isCardView
                                  ? Icons.view_agenda
                                  : Icons.view_stream,
                              color: Color(0XFF2563EB),
                            ),
                            onPressed: () {
                              setState(() {
                                isCardView = !isCardView;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                isCardView
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          return buildCardProfile(index, filtered);
                        },
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return buildRowProfile(index, filtered);
                        },
                      ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: syncedUsers.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: Color(0XFF2563EB),
              child: Icon(Icons.chat, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Contacts()),
                );
              },
            ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: BottomNavigationBar(
          key: ValueKey("nav"),
          currentIndex: 0,
          selectedItemColor: Color(0XFF2563EB),
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chats"),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: "People"),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: "Settings"),
          ],
        ),
      ),
    );
  }

  Widget buildCardProfile(int index, List users) {
    if (index >= users.length) {
      return SizedBox();
    }
    final user = users[index];
    bool _isTapped = false; // local for animation

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          // LONG PRESS ON CARD → select profile
          onLongPress: () {
            print(
              "Card long pressed: ${user["name"]}",
            ); // you can handle selection here
          },
          onTapDown: (_) => setState(() => _isTapped = true),
          onTapUp: (_) => setState(() => _isTapped = false),
          onTapCancel: () => setState(() => _isTapped = false),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Message(
                  contactName: (user["name"] ?? "").toString(),
                  contactUserId: (user["userId"] ?? "").toString(),
                  contactImage: (user["image"] ?? "").toString(),
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 100),
            curve: Curves.easeOut,
            margin: EdgeInsets.all(4),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isTapped
                  ? const Color.fromARGB(255, 197, 225, 244)
                  : Colors.white, // tap effect
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isTapped ? 0.1 : 0.04),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// PROFILE + TIME
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // LONG PRESS ONLY ON AVATAR → FULL SCREEN IMAGE
                    SizedBox(height: 4),
                    GestureDetector(
                      onLongPress: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.9),
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.transparent,
                            body: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Center(
                                child: InteractiveViewer(
                                  child: Image.asset(
                                    user["image"],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: user["image"] != null
                            ? NetworkImage(user["image"])
                            : null,
                        child:
                            user["image"] == null ? Icon(Icons.person) : null,
                      ),
                    ),

                    // TIME TOP RIGHT
                    Positioned(
                      right: -18,
                      top: -15,
                      child: Text(
                        user["time"] ?? "",
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color.fromARGB(255, 112, 112, 112),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 6),

                /// NAME
                highlightText(
                  (user["name"] ?? "").length > 10
                      ? "${user["name"].toString().substring(0, 10)}..."
                      : user["name"] ?? "",
                ),
                SizedBox(height: 4),

                /// STATUS + ACTIVITY
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (user["message"] ?? "").toString().length >= 6
                          ? "${user["message"].toString().substring(0, 6)}..."
                          : user["message"] ?? "",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _buildMessageStatus(user["status"]),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Inside your _ChatState class

  Widget buildRowProfile(int index, List users) {
    if (index >= users.length) {
      return SizedBox();
    }
    final user = users[index];
    bool _isTapped = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          // LONG PRESS ON CARD → select profile (same as before)
          onLongPress: () {
            print("Card long pressed: ${safeString(user["name"])}");
          },
          onTapDown: (_) => setState(() => _isTapped = true),
          onTapUp: (_) => setState(() => _isTapped = false),
          onTapCancel: () => setState(() => _isTapped = false),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Message(
                  contactName: (user["name"] ?? "").toString(),
                  contactUserId: (user["userId"] ?? "").toString(),
                  contactImage: (user["image"] ?? "").toString(),
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 100),
            curve: Curves.easeOut,
            margin: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: EdgeInsets.all(8),
            width: double.infinity, // full width
            decoration: BoxDecoration(
              color: _isTapped
                  ? const Color.fromARGB(255, 197, 225, 244)
                  : Colors.white, // hover effect
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isTapped ? 0.1 : 0.04),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                /// AVATAR
                GestureDetector(
                  onLongPress: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.9),
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.transparent,
                        body: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Center(
                            child: InteractiveViewer(
                              child: Image.asset(
                                user["image"],
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: user["image"] != null
                        ? NetworkImage(user["image"])
                        : null,
                    child: user["image"] == null ? Icon(Icons.person) : null,
                  ),
                ),

                SizedBox(width: 12),

                /// NAME & LAST IMAGE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      highlightText(
                        safeString(user["name"]).length > 20
                            ? "${safeString(user["name"]).substring(0, 20)}..."
                            : safeString(user["name"]),
                      ),
                      SizedBox(height: 6),
                      // Replace with actual last image from chat
                      Text(
                          (user["message"] ?? "").toString().length > 18
                              ? "${user["message"].toString().substring(0, 18)}..."
                              : user["message"] ?? "",
                          style: TextStyle(
                              fontSize: 14,
                              color: const Color.fromARGB(255, 114, 114, 114))),
                    ],
                  ),
                ),

                /// TIME & STATUS
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      user["time"] ?? "",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    _buildMessageStatus(user["status"]?.toString() ?? ""),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget highlightText(String text) {
    final query = _searchController.text;

    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
      );
    }

    final start = lowerText.indexOf(lowerQuery);
    final end = start + lowerQuery.length;

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14),
        children: [
          TextSpan(
            text: text.substring(0, start),
            style: TextStyle(color: Colors.black),
          ),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(
              color: Color(0XFF2563EB),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: text.substring(end),
            style: TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatus(String? status) {
    if (status == "sent") {
      return Icon(
        Icons.circle_outlined,
        size: 12,
        color: const Color.fromARGB(255, 108, 117, 242),
      );
    }

    if (status == "delivered") {
      return Row(
        children: [
          Icon(Icons.circle, size: 10, color: Colors.blueAccent),
          SizedBox(width: 0),
          Icon(Icons.circle, size: 10, color: Colors.blueAccent),
        ],
      );
    }

    if (status == "seen") {
      return Row(
        children: [
          Icon(Icons.circle, size: 10, color: Colors.green),
          SizedBox(width: 0),
          Icon(Icons.circle, size: 10, color: Colors.green),
        ],
      );
    }

    return SizedBox();
  }
}
