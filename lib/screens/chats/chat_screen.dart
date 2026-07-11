import 'package:flutter/material.dart';
import 'package:talkie_new/screens/chats/message_screen.dart';
import 'package:talkie_new/screens/chats/addContact_screen.dart';
import 'package:talkie_new/screens/chats/contacts.dart';
import 'package:talkie_new/screens/splash/splash_screen.dart';
import 'package:talkie_new/services/auth_service.dart';
import 'package:talkie_new/screens/profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/database/db_helper.dart';
import 'package:talkie_new/services/chat_service.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class Chat extends StatefulWidget {
  const Chat({
    Key? key,
  }) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late Future<List<Map<String, dynamic>>> _chatFuture;
  late DBHelper _dbHelper;
  bool selectionMode = false;
  String? hoveredChat;

  Set<String> selectedChats = {}; // stores chatId or otherUserId

  String? getChatId(Map<String, dynamic> chat, String uid) {
    final u1 = chat["user1"];
    final u2 = chat["user2"];
    return "${u1}_$u2"; // stable identifier
  }

  String formatTime(dynamic timestamp) {
    if (timestamp == null) return "";

    DateTime dt;

    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is int) {
      // if you're storing milliseconds in SQLite
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return "";
    }

    final now = DateTime.now();

    String timeString;

    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');

    String period = hour >= 12 ? "PM" : "AM";

    // convert 24h → 12h format
    hour = hour % 12;
    if (hour == 0) hour = 12;

    timeString = "$hour:$minute $period";

    // show only time if today, else date
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return timeString;
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

  List<Map<String, dynamic>> get filteredUsers {
    if (_searchController.text.isEmpty) {
      return syncedUsers;
    }

    final query = _searchController.text.toLowerCase();

    return syncedUsers.where((user) {
      final name = (user["name"] ?? "").toString().toLowerCase();
      final phone = (user["phone"] ?? "").toString().toLowerCase();

      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> syncedUsers = [];

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
    _dbHelper = DBHelper(currentUser.uid);
    _chatFuture = _dbHelper.getChats(currentUser.uid);

    _chatListener = FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: currentUser.uid)
        .snapshots();

    _chatListener.listen((snapshot) async {
      final service = ChatService(currentUser.uid);

      for (final change in snapshot.docChanges) {
        final chatId = change.doc.id;

        await service.syncChatPreview(chatId);
      }

      await loadChats();
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    _dbHelper = DBHelper(uid);
    ChatService(uid).syncMessages();

    ChatService.chatUpdated.addListener(() async {
      final chatId = ChatService.chatUpdated.value;

      if (chatId == null) return;

      await loadChats();
    });
  }

  Future<void> loadChats() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final chats = await _dbHelper.getChats(uid);

    List<Map<String, dynamic>> chatUsers = [];

    for (var chat in chats) {
      String otherUserId = chat["user1"] == uid ? chat["user2"] : chat["user1"];

      final contact = await _dbHelper.getContactByUserId(otherUserId);
      print("");
      print("CONTACT:");
      print(contact);
      print("");

      final status = chat["status"] ?? "sent";
      final lastSenderId = chat["lastSenderId"];
      if (contact != null) {
        chatUsers.add({
          "userId": otherUserId.toString(),
          "user1": chat["user1"].toString(),
          "user2": chat["user2"].toString(),
          "name": contact["name"]?.toString() ?? "Unknown",
          "phone": contact["phone"]?.toString() ?? "",
          "image": contact["imageUrl"]?.toString() ?? "",
          "message": chat["lastMessage"]?.toString() ?? "",
          "time": formatTime(chat["lastMessageTime"]),
          "status": status,
          "lastSenderId": lastSenderId,
        });
        print("USER ADDED");
        print(chatUsers.last);
      }
    }
    setState(() {
      syncedUsers = chatUsers;
      _chatFuture = _dbHelper.getChats(uid); // 🔥 FORCE RELOAD
    });
    print("🔥 Chats found in SQLite: ${chats.length}");
    print(chats);
  }

  void enterSelectionMode(String chatId) {
    setState(() {
      selectionMode = true;
      selectedChats.add(chatId);
    });
  }

  Widget chatSelectionWrapper({
    required String chatId,
    required Widget child,
  }) {
    final isSelected = selectedChats.contains(chatId);
    final index = selectedChats.toList().indexOf(chatId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          child,
          if (isSelected)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSearching = false;
  bool isCardView = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    //final users = filteredUsers;

    return Scaffold(
      appBar: selectionMode
          ? AppBar(
              backgroundColor: Color(0XFF2563EB),
              leading: IconButton(
                icon: Icon(Icons.close,
                    color: const Color.fromARGB(255, 255, 255, 255)),
                onPressed: () {
                  setState(() {
                    selectionMode = false;
                    selectedChats.clear();
                  });
                },
              ),
              title: Text("${selectedChats.length} selected",
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
              actions: [
                IconButton(
                  icon: Icon(Icons.push_pin,
                      color: const Color.fromARGB(255, 255, 255, 255)),
                  onPressed: () {
                    print("Pin chats: $selectedChats");
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    print("Delete chats: $selectedChats");
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                  ),
                  color: Colors.white,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  offset: Offset(0, 40),
                  onSelected: (value) {
                    if (value == "clear") {
                      print("Clear chat");
                      setState(() {
                        selectionMode = false;
                        selectedChats.clear();
                      });
                    } else if (value == "block") {
                      print("Block chat");
                      setState(() {
                        selectionMode = false;
                        selectedChats.clear();
                      });
                    } else if (value == "read") {
                      print("Mark as read");
                      setState(() {
                        selectionMode = false;
                        selectedChats.clear();
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "clear",
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 20, color: Colors.black87),
                          SizedBox(width: 10),
                          Text("Clear chat"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "block",
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 20, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text("Block chat"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "read",
                      child: Row(
                        children: [
                          Icon(Icons.mark_chat_read,
                              size: 20, color: Colors.green),
                          SizedBox(width: 10),
                          Text("Mark as read"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        hintText: "Search...",
                        border: InputBorder.none,
                      ),
                    )
                  : Row(
                      children: [
                        Image.asset(
                          "assets/images/logo.png",
                          height: 40,
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          "assets/images/logo_text.png",
                          height: 18,
                        ),
                      ],
                    ),
              actions: [
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    splashRadius: 22,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  IconButton(
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.search,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.black87,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    offset: const Offset(0, 45),
                    onSelected: (value) async {
                      if (value == "profile") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(),
                          ),
                        );
                      }

                      if (value == "settings") {
                        // Settings page later
                      }

                      if (value == "logout") {
                        // Allow popup menu to close first
                        await Future.delayed(
                          const Duration(milliseconds: 150),
                        );

                        if (!context.mounted) return;

                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return Dialog(
                              backgroundColor: Colors.white,
                              elevation: 12,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.logout_rounded,
                                        color: Colors.red,
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      "Logout",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Are you sure you want to logout from your Talkie account?.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {
                                              Navigator.pop(
                                                dialogContext,
                                                false,
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.black87,
                                              side: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text(
                                              "Cancel",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(
                                                dialogContext,
                                                true,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.logout_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "Logout",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
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

                        if (shouldLogout == true) {
                          await AuthService().logout();

                          if (!context.mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Welcome_Talkie(),
                            ),
                            (_) => false,
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "profile",
                        child: Row(
                          children: const [
                            Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 12),
                            Text("Profile"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "settings",
                        child: Row(
                          children: const [
                            Icon(
                              Icons.settings,
                              size: 20,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 12),
                            Text("Settings"),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: "logout",
                        child: Row(
                          children: const [
                            Icon(
                              Icons.logout,
                              size: 20,
                              color: Colors.red,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Logout",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
      body: RefreshIndicator(
        onRefresh: loadChats,
        child: FutureBuilder(
          future: _chatFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final currentUser = FirebaseAuth.instance.currentUser!;
            final chats = snapshot.data!;

            final filtered = chats.where((chat) {
              final contact = syncedUsers.firstWhere(
                (u) =>
                    u["userId"] ==
                    (chat["user1"] == FirebaseAuth.instance.currentUser!.uid
                        ? chat["user2"]
                        : chat["user1"]),
                orElse: () => {},
              );

              final name = (contact["name"] ?? "").toString().toLowerCase();
              final phone = (contact["phone"] ?? "").toString().toLowerCase();
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
                    color: Colors.white,
                    padding: EdgeInsets.all(16),
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
                                final chat = filtered[index];

                                final currentUserId =
                                    FirebaseAuth.instance.currentUser!.uid;

                                String otherUserId =
                                    chat["user1"] == currentUserId
                                        ? chat["user2"]
                                        : chat["user1"];

                                return FutureBuilder<Map<String, dynamic>?>(
                                  future: _dbHelper.getChatContact(
                                    otherUserId,
                                  ),
                                  builder: (context, snapshot) {
                                    final contact = snapshot.data;

                                    final name = contact?["name"] ?? "Unknown";
                                    final image = contact?["imageUrl"] ??
                                        contact?["imagePath"];

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundImage: (image != null &&
                                                    image.toString().isNotEmpty)
                                                ? (image
                                                        .toString()
                                                        .startsWith("http")
                                                    ? NetworkImage(image)
                                                    : FileImage(File(image))
                                                        as ImageProvider)
                                                : null,
                                            child: (image == null ||
                                                    image == "")
                                                ? Icon(
                                                    Icons.person,
                                                    size: 30,
                                                    color: Color(0XFF2563EB),
                                                  )
                                                : null,
                                          ),
                                          SizedBox(height: 6),
                                          highlightText(
                                            name.length > 10
                                                ? "${name.substring(0, 10)}..."
                                                : name,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }),
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
                                selectionMode
                                    ? (selectedChats.length == filtered.length
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked)
                                    : (isCardView
                                        ? Icons.view_agenda
                                        : Icons.view_stream),
                                color: const Color(0XFF2563EB),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  // =========================
                                  // 🟢 NORMAL MODE (VIEW TOGGLE)
                                  // =========================
                                  if (!selectionMode) {
                                    isCardView = !isCardView;
                                    return;
                                  }

                                  // =========================
                                  // 🔵 SELECTION MODE LOGIC
                                  // =========================

                                  // if first time entering selection mode via icon
                                  if (selectedChats.isEmpty) {
                                    selectedChats = filtered
                                        .map((c) =>
                                            "${c["user1"]}_${c["user2"]}")
                                        .toSet();
                                    return;
                                  }

                                  // toggle select all / clear all
                                  if (selectedChats.length == filtered.length) {
                                    selectedChats.clear();
                                    //selectionMode = false;
                                  } else {
                                    selectedChats = filtered
                                        .map((c) =>
                                            "${c["user1"]}_${c["user2"]}")
                                        .toSet();
                                  }
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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

  Widget buildCardProfile(int index, List<Map<String, dynamic>> users) {
    if (index >= users.length) {
      return SizedBox();
    }

    final chat = users[index];

    if (chat is! Map<String, dynamic>) {
      return const SizedBox();
    }

    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final otherUserId =
        (chat["user1"] ?? "") == currentUserId ? chat["user2"] : chat["user1"];

    if (otherUserId == null) return const SizedBox();
    print(chat);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _dbHelper.getChatContact(otherUserId),
      builder: (context, snapshot) {
        final contact = snapshot.data;

        final name = contact?["name"] ?? "Unknown";
        final image = contact?["imageUrl"] ?? contact?["imagePath"];
        final phone = contact?["phone"] ?? "";

        bool _isTapped = false;

        return StatefulBuilder(
          builder: (context, localSetState) {
            return chatSelectionWrapper(
              chatId: "${chat["user1"]}_${chat["user2"]}",
              child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(0),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(0),
                    splashColor: const Color(0XFF2563EB).withOpacity(0.25),
                    highlightColor: const Color.fromARGB(255, 207, 222, 255).withOpacity(0.25),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();

                      this.setState(() {
                        selectionMode = true;

                        final chatId = "${chat["user1"]}_${chat["user2"]}";

                        enterSelectionMode(chatId);
                        selectedChats.add(chatId);
                      });
                    },
                    onTap: () async {
                      if (selectionMode) {
                        final chatId = "${chat["user1"]}_${chat["user2"]}";

                        this.setState(() {
                          if (selectedChats.contains(chatId)) {
                            selectedChats.remove(chatId);
                            HapticFeedback.lightImpact();
                          } else {
                            selectedChats.add(chatId);
                            HapticFeedback.lightImpact();
                          }

                          if (selectedChats.isEmpty) {
                            selectionMode = false;
                          }

                          hoveredChat = null;
                          _isTapped = false;
                        });

                        return;
                      }

                      await Future.delayed(const Duration(milliseconds: 250));

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Message(
                            contactName: name,
                            contactUserId: otherUserId,
                            contactImage: image ?? "",
                          ),
                        ),
                      );

                      if (mounted) {
                        this.setState(() {
                          hoveredChat = null;
                          _isTapped = false;
                        });
                      }
                    },
                    onTapDown: (_) {
                      this.setState(() {
                        _isTapped = true;
                        hoveredChat = "${chat["user1"]}_${chat["user2"]}";
                      });
                    },
                    onTapCancel: () {
                      this.setState(() {
                        _isTapped = false;
                        hoveredChat = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 100),
                      curve: Curves.easeOut,
                      margin: EdgeInsets.all(0.2),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedChats
                                .contains("${chat["user1"]}_${chat["user2"]}")
                            ? Colors.blue.withOpacity(0.15)
                            : hoveredChat == "${chat["user1"]}_${chat["user2"]}"
                                ? const Color.fromARGB(255, 179, 220, 253).withOpacity(0.15)
                                : Colors.white,
                        borderRadius: selectedChats
                                .contains("${chat["user1"]}_${chat["user2"]}")
                            ? BorderRadius.circular(0)
                            : BorderRadius.circular(0),
                        boxShadow: selectedChats
                                .contains("${chat["user1"]}_${chat["user2"]}")
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.2),
                                  blurRadius: 0,
                                )
                              ]
                            : [
                                BoxShadow(
                                  color: hoveredChat ==
                                          "${chat["user1"]}_${chat["user2"]}"
                                      ? const Color.fromARGB(255, 195, 226, 252).withOpacity(0.25)
                                      : Colors.black.withOpacity(0.04),
                                  blurRadius: hoveredChat ==
                                          "${chat["user1"]}_${chat["user2"]}"
                                      ? 10
                                      : 6,
                                  spreadRadius: hoveredChat ==
                                          "${chat["user1"]}_${chat["user2"]}"
                                      ? 1
                                      : 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          /// PROFILE + TIME dfidokgd
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(height: 4),
                              GestureDetector(
                                onLongPress: () {
                                  if (image == null || image.toString().isEmpty)
                                    return;

                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black.withOpacity(0.9),
                                    builder: (_) => Scaffold(
                                      backgroundColor: Colors.transparent,
                                      body: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Center(
                                          child: InteractiveViewer(
                                            child: (image
                                                    .toString()
                                                    .startsWith("http"))
                                                ? Image.network(
                                                    image!,
                                                    fit: BoxFit.contain,
                                                  )
                                                : Image.file(
                                                    File(image),
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
                                  backgroundImage: (image != null &&
                                          image.toString().isNotEmpty)
                                      ? (image.toString().startsWith("http")
                                          ? NetworkImage(image)
                                          : FileImage(File(image))
                                              as ImageProvider)
                                      : null,
                                  child: (image == null || image == "")
                                      ? Icon(
                                          Icons.person,
                                          color: Color(0XFF2563EB),
                                          size: 30,
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                right: -18,
                                top: -15,
                                child: Text(
                                  formatTime(chat["lastMessageTime"]),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color.fromARGB(
                                        255, 112, 112, 112),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 6),

                          /// NAME
                          highlightText(
                            name.length > 10
                                ? "${name.substring(0, 10)}..."
                                : name,
                          ),

                          SizedBox(height: 4),

                          /// STATUS + ACTIVITY
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                (chat["lastMessage"] ?? "").toString().isEmpty
                                    ? ""
                                    : (chat["lastMessage"] ?? "")
                                                .toString()
                                                .length >
                                            6
                                        ? "${(chat["lastMessage"] ?? "").toString().substring(0, 6)}..."
                                        : (chat["lastMessage"] ?? "")
                                            .toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              chat["lastSenderId"] ==
                                      FirebaseAuth.instance.currentUser!.uid
                                  ? _buildMessageStatus(
                                      chat["status"]?.toString())
                                  : SizedBox(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            );
          },
        );
      },
    );
  } // Inside your _ChatState class

  Widget buildRowProfile(int index, List<Map<String, dynamic>> users) {
    if (index >= users.length) {
      return SizedBox();
    }
    final chat = users[index];

    if (chat is! Map<String, dynamic>) {
      return SizedBox(); // prevent crash
    }
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final otherUserId =
        (chat["user1"] ?? "") == currentUserId ? chat["user2"] : chat["user1"];

    if (otherUserId == null) return const SizedBox();

    bool _isTapped = false;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _dbHelper.getChatContact(otherUserId),
      builder: (context, snapshot) {
        final contact = snapshot.data;

        final name = contact?["name"] ?? "Unknown";
        final image = contact?["imageUrl"] ?? contact?["imagePath"];

        return StatefulBuilder(
          builder: (context, localSetState) {
            return chatSelectionWrapper(
              chatId: "${chat["user1"]}_${chat["user2"]}",
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(0),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(0),
                  splashColor: const Color(0XFF2563EB).withOpacity(0.25),
                  highlightColor: const Color.fromARGB(255, 207, 222, 255).withOpacity(0.25),
                  onLongPress: () {
                    HapticFeedback.mediumImpact();

                    this.setState(() {
                      selectionMode = true;

                      final chatId = "${chat["user1"]}_${chat["user2"]}";

                      enterSelectionMode(chatId);
                      selectedChats.add(chatId);
                    });
                  },
                  onTap: () async {
                    if (selectionMode) {
                      final chatId = "${chat["user1"]}_${chat["user2"]}";

                      this.setState(() {
                        if (selectedChats.contains(chatId)) {
                          selectedChats.remove(chatId);
                          HapticFeedback.lightImpact();
                        } else {
                          selectedChats.add(chatId);
                          HapticFeedback.lightImpact();
                        }

                        if (selectedChats.isEmpty) {
                          selectionMode = false;
                        }

                        hoveredChat = null;
                        _isTapped = false;
                      });

                      return;
                    }

                    await Future.delayed(const Duration(milliseconds: 250));

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Message(
                          contactName: name,
                          contactUserId: otherUserId,
                          contactImage: image ?? "",
                        ),
                      ),
                    );

                    if (mounted) {
                      this.setState(() {
                        hoveredChat = null;
                        _isTapped = false;
                      });
                    }
                  },
                  onTapDown: (_) {
                    this.setState(() {
                      _isTapped = true;
                      hoveredChat = "${chat["user1"]}_${chat["user2"]}";
                    });
                  },
                  onTapCancel: () {
                    this.setState(() {
                      _isTapped = false;
                      hoveredChat = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    //margin: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: selectedChats
                                .contains("${chat["user1"]}_${chat["user2"]}")
                            ? Colors.blue.withOpacity(0.15)
                            : hoveredChat == "${chat["user1"]}_${chat["user2"]}"
                                ? const Color.fromARGB(255, 179, 220, 253).withOpacity(0.15)
                                : Colors.white,
                        boxShadow: selectedChats
                                .contains("${chat["user1"]}_${chat["user2"]}")
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.2),
                                  blurRadius: 0,
                                )
                              ]
                            : [
                                BoxShadow(
                                  color: hoveredChat ==
                                          "${chat["user1"]}_${chat["user2"]}"
                                      ? const Color.fromARGB(164, 219, 219, 219).withOpacity(0.25)
                                      : Colors.black.withOpacity(0.04),
                                  blurRadius: hoveredChat ==
                                          "${chat["user1"]}_${chat["user2"]}"
                                      ? 10
                                      : 6,
                                  spreadRadius: hoveredChat ==
                                          "${chat["user1"]}_${chat["user2"]}"
                                      ? 1
                                      : 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          /// AVATAR
                          GestureDetector(
                            onLongPress: () {
                              if (image == null || image.toString().isEmpty)
                                return;

                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.9),
                                builder: (_) => Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Center(
                                      child: InteractiveViewer(
                                        child: (image
                                                .toString()
                                                .startsWith("http"))
                                            ? Image.network(
                                                image!,
                                                fit: BoxFit.contain,
                                              )
                                            : Image.file(
                                                File(image),
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
                              backgroundImage: (image != null &&
                                      image.toString().isNotEmpty)
                                  ? (image.toString().startsWith("http")
                                      ? NetworkImage(image)
                                      : FileImage(File(image)) as ImageProvider)
                                  : null,
                              child: (image == null || image == "")
                                  ? Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Color(0XFF2563EB),
                                    )
                                  : null,
                            ),
                          ),

                          SizedBox(width: 12),

                          /// NAME & LAST MESSAGE
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                highlightText(
                                  name.length > 20
                                      ? "${name.substring(0, 20)}..."
                                      : name,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  (chat["lastMessage"] ?? "")
                                              .toString()
                                              .length >
                                          18
                                      ? "${(chat["lastMessage"] ?? "").toString().substring(0, 18)}..."
                                      : (chat["lastMessage"] ?? "").toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// TIME & STATUS
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatTime(chat["lastMessageTime"]),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              SizedBox(height: 8),
                              chat["lastSenderId"] ==
                                      FirebaseAuth.instance.currentUser!.uid
                                  ? _buildMessageStatus(
                                      chat["status"]?.toString())
                                  : SizedBox(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
        Icons.check_circle_outline,
        size: 13,
        color: Color(0xFF6C75F2),
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
