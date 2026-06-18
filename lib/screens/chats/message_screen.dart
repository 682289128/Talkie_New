import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/services/chat_service.dart';
import 'package:talkie_new/widgets/message_bubble.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:talkie_new/database/db_helper.dart';

class Message extends StatefulWidget {
  final String contactName;
  final String contactImage;
  final String contactUserId;

  const Message(
      {Key? key,
      required this.contactName,
      required this.contactUserId,
      required this.contactImage})
      : super(key: key);

  @override
  State<Message> createState() => _MessageState();
}

class _MessageState extends State<Message> with WidgetsBindingObserver {
  final DBHelper _dbHelper = DBHelper();
  bool isNavigatingToReply = false;
  bool shouldAutoScroll = true;
  bool hasInitiallyScrolled = false;
  List<QueryDocumentSnapshot> currentDocs = [];
  final FocusNode _textFocusNode = FocusNode();

  String? focusedMessageId;
  Map<int, double> swipeOffset = {};
  Map<int, bool> canSwipe = {};

  double horizontalThreshold = 12;
  double verticalThreshold = 18;
  String? highlightedMessageId;
  String? deletedHighlightedId;
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();

  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final currentUser = FirebaseAuth.instance.currentUser!;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> localMessages = [];
  bool isLocalLoaded = false;

  Map<String, String> userNames = {};

  Map<String, dynamic>?
      replyingTo; // keeps track of the message being replied to

  int?
      replyingToIndex; // tracks which message is being replied to for highlighting

  int? editingIndex; // tracks which message is being edited
  String? editingMessageId; // 🔥 real message id for editing

  bool reverseChat = true;
  // 🟦 MULTI SELECT MODE
  bool isSelectionMode = false;

// selected message IDs (ORDER matters for numbering)
  List<String> selectedMessages = [];
  bool dragSelectionEnabled = false;
  Future<void> sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final messageText = _controller.text.trim();

    // 🔥 EDIT MODE
    if (editingMessageId != null) {
      try {
        await _chatService.updateMessage(
          messageId: editingMessageId!,
          newText: messageText,
          senderId: currentUser.uid,
          receiverId: widget.contactUserId,
        );

        setState(() {
          editingIndex = null;
          editingMessageId = null;
          highlightedMessageId = null;
        });

        _controller.clear();
        return;
      } catch (e) {
        print("EDIT ERROR: $e"); // 👈 VERY IMPORTANT
      }
    }

    Future<bool> hasInternet() async {
      try {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    final messageId = _firestore.collection("dummy").doc().id;
    // 🟢 NORMAL SEND

    final isOnline = await hasInternet();

    await _chatService.saveMessageLocally(
      messageId: messageId,
      senderId: currentUser.uid,
      receiverId: widget.contactUserId,
      text: messageText,
      replyTo: replyingTo?["text"],
      replyToId: replyingTo?["messageId"],
    );

    final status = isOnline ? "sent" : "pending";

    await _dbHelper.updateMessageStatus(messageId, status);

    _chatService.sendMessage(
      messageId: messageId,
      senderId: currentUser.uid,
      receiverId: widget.contactUserId,
      text: messageText,
      replyTo: replyingTo?["text"],
      replyToId: replyingTo?["messageId"],
    );

// 💥 UPDATE LOCAL SQLITE STATUS

// 💥 RELOAD UI
    await _loadLocalMessages();

    if (mounted) setState(() {});

    _controller.clear();

    setState(() {
      replyingTo = null;
      replyingToIndex = null;
      highlightedMessageId = null;
      swipeOffset.clear();
    });
    scrollToBottom(currentDocs);

    shouldAutoScroll = false;
  }

  Future<void> _loadUserNames() async {
    final db = await _dbHelper.database;

    final users = await db.query('users');

    final contacts = await db.query('contacts');

    final all = [...users, ...contacts];

    Map<String, String> map = {};

    for (var u in all) {
      final id = (u["userId"] ?? u["email"])?.toString();
      final name = (u["name"] ?? "Unknown").toString();

      if (id != null) {
        map[id] = name;
      }
    }

    setState(() {
      userNames = map;
    });
  }

  Future<void> _handleDeleteMessage(String messageId) async {
    FocusScope.of(context).unfocus(); // 🔥 ADD THIS FIRST
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Delete message",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose how you want to delete this message",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // TEMPORARY
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, "temporary");
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0XFF2563EB).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restore, color: Color(0XFF2563EB)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Temporary (can be restored)",
                          style: TextStyle(
                            color: Color(0XFF2563EB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // PERMANENT
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, "permenent");
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Permanent (Cannot be restored)",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      _removeKeyboardFocus();
      await _chatService.deleteMessage(
        messageId: messageId,
        senderId: currentUser.uid,
        receiverId: widget.contactUserId,
        type: result,
      );

      await _loadLocalMessages();

      setState(() {});

      _removeKeyboardFocus();
    }
  }

  Future<void> _loadLocalMessages() async {
    final messages = await _dbHelper.getMessages(
      currentUser.uid,
      widget.contactUserId,
    ); // you already use DBHelper

    setState(() {
      localMessages = messages;
      isLocalLoaded = true;
    });
  }

  String getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(msgDay).inDays;

    final time = _formatTime(date);

    // 🟢 Today
    if (difference == 0) {
      return "Today at $time";
    }

    // 🟡 Yesterday
    if (difference == 1) {
      return "Yesterday at $time";
    }

    // 🔵 2–5 days ago → weekday
    if (difference >= 2 && difference <= 5) {
      return "${_weekdayName(date.weekday)} at $time";
    }

    // 🟣 older → full date
    return "${date.day} ${_monthName(date.month)} ${date.year} at $time";
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? "PM" : "AM";

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "$hour:$minute $period";
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return "Monday";
      case 2:
        return "Tuesday";
      case 3:
        return "Wednesday";
      case 4:
        return "Thursday";
      case 5:
        return "Friday";
      case 6:
        return "Saturday";
      case 7:
        return "Sunday";
      default:
        return "";
    }
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) return value.toDate();

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return "January";
      case 2:
        return "February";
      case 3:
        return "March";
      case 4:
        return "April";
      case 5:
        return "May";
      case 6:
        return "June";
      case 7:
        return "July";
      case 8:
        return "August";
      case 9:
        return "September";
      case 10:
        return "October";
      case 11:
        return "November";
      case 12:
        return "December";
      default:
        return "";
    }
  }

  String formatSeenTime(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? "PM" : "AM";

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "$hour:$minute $period";
  }

  Widget seenText(Timestamp? seenAt) {
    if (seenAt == null) return const SizedBox.shrink();

    final date = seenAt.toDate();

    return Text(
      "Seen • ${formatSeenTime(date)}",
      style: const TextStyle(
        fontSize: 10,
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  void openFullScreenInput() {
    FocusScope.of(context).unfocus(); // 🔥 IMPORTANT
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(top: 20),
            child: Column(
              children: [
                /// 🔹 Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Write Message",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                /// 🔹 Full screen text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: "Type your long message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                /// 🔹 SEND BUTTON ✅
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      sendMessage(); // use existing logic
                      Navigator.pop(context); // close fullscreen
                    },
                    icon: Icon(Icons.send),
                    label: Text("Send"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0XFF2563EB),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget messageStatusIcon(String status) {
    Color baseColor;
    int dotCount = 1; // default = single dot

    switch (status) {
      case "pending":
        baseColor = Colors.orangeAccent; // 🟠 sending state
        dotCount = 1;
        break;

      case "sent":
        baseColor = const Color.fromARGB(255, 239, 239, 239);
        dotCount = 1;
        break;

      case "delivered":
        baseColor = const Color.fromARGB(255, 255, 255, 255);
        dotCount = 2;
        break;

      case "seen":
      case "read":
        baseColor = Colors.greenAccent;
        dotCount = 2;
        break;

      default:
        baseColor = Colors.white70;
        dotCount = 1;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(dotCount, (index) {
        return Container(
          margin: const EdgeInsets.only(left: 3),
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: baseColor,
            shape: BoxShape.circle,
            boxShadow: status == "seen" || status == "read"
                ? [
                    BoxShadow(
                      color: Colors.lightBlueAccent.withOpacity(0.7),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : status == "delivered"
                    ? [
                        BoxShadow(
                          color: Colors.amberAccent.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : [],
          ),
        );
      }),
    );
  }

  Widget messageGlowWrapper({
    required String messageId,
    required Widget child,
  }) {
    final isFocused = focusedMessageId == messageId;
    final isEditing = editingMessageId == messageId;
    final isSelected = selectedMessages.contains(messageId);

    final selectedIndex = selectedMessages.indexOf(messageId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withOpacity(0.18)
            : isEditing
                ? Colors.blue.withOpacity(0.15)
                : isFocused
                    ? Colors.blue.withOpacity(0.20)
                    : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: Colors.blueAccent, width: 1.5)
            : isEditing
                ? Border.all(color: Colors.blueAccent, width: 1)
                : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : isEditing
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
      ),
      child: Stack(
        children: [
          child,

          // 🔵 NUMBER BADGE (only when selected)
          if (isSelected)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "${selectedIndex + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  handleSwipeReply(
    String text,
    String messageId,
    int index,
    List<Map<String, dynamic>> docs,
  ) {
    replyingTo = {
      "text": text,
      "messageId": messageId,
    };

    replyingToIndex = index;

    HapticFeedback.selectionClick();

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final focus = FocusScope.of(context);

      // 🔥 always ensure a clean reset cycle
      focus.unfocus();

      Future.delayed(const Duration(milliseconds: 30), () {
        if (!mounted) return;
        focus.requestFocus(_textFocusNode);
      });
    });
  }

  void scrollToBottom(List docs) {
    if (!shouldAutoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (docs.isEmpty) return;

      if (!_itemScrollController.isAttached) return;

      try {
        await _itemScrollController.scrollTo(
          index: localMessages.length - 1,
          duration: Duration.zero,
          curve: Curves.easeOut,
          alignment: 0.0,
        );
      } catch (e) {
        debugPrint("Scroll error: $e");
      }
    });
  }

  Future<List> _getCurrentDocs() async {
    final snapshot = await _chatService
        .getMessages(currentUser.uid, widget.contactUserId)
        .first;

    return snapshot.docs;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.unfocus();
    });
    WidgetsBinding.instance.addObserver(this);

    _setOnlineStatus(true);

    _loadLocalMessages();

    _loadUserNames();

    FirebaseFirestore.instance
        .collection("users")
        .doc(widget.contactUserId) // 🔥 OTHER USER
        .snapshots()
        .listen((snapshot) async {
      final isOnline = snapshot.data()?["isOnline"] ?? false;

      if (isOnline) {
        await _chatService.markMessagesAsDelivered(
          currentUserId: widget.contactUserId,
          otherUserId: currentUser.uid,
        );
      }
    });

    _chatService
        .getMessages(currentUser.uid, widget.contactUserId)
        .listen((snapshot) async {
      await _chatService.markAsSeen(
        senderId: widget.contactUserId,
        receiverId: currentUser.uid,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _chatService.retryPendingMessages(
        senderId: currentUser.uid,
        receiverId: widget.contactUserId,
      );
    } else if (state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .update({
      "isOnline": isOnline,
      "lastSeen": FieldValue.serverTimestamp(),
    });
  }

  void _removeKeyboardFocus() {
    FocusManager.instance.primaryFocus?.unfocus();

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,

      // 🔹 APP BAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Stack(
          children: [
            // 🔵 YOUR ORIGINAL APPBAR
            AppBar(
              elevation: 1,
              backgroundColor: Colors.white,
              leadingWidth: 30,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.contactImage.isNotEmpty
                        ? NetworkImage(widget.contactImage)
                        : null,
                    child:
                        widget.contactImage.isEmpty ? Icon(Icons.person) : null,
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contactName,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Online",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.swap_vert),
                  onPressed: () {
                    setState(() {
                      reverseChat = !reverseChat;
                    });

                    Future.delayed(Duration(milliseconds: 100), () {
                      if (_itemScrollController.isAttached) {
                        _itemScrollController.scrollTo(
                          index: reverseChat ? 0 : 999999,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  },
                ),
              ],
              iconTheme: IconThemeData(color: Colors.black),
            ),

            // 🔵 MULTI SELECT BAR (ONLY SHOW WHEN ACTIVE)
            if (isSelectionMode)
              Positioned.fill(
                child: Material(
                  elevation: 2,
                  color: Colors.blue.shade700,
                  child: SafeArea(
                    child: Row(
                      children: [
                        // CLOSE / EXIT
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              isSelectionMode = false;
                              selectedMessages.clear();
                            });
                          },
                        ),

                        // COUNT
                        Text(
                          "${selectedMessages.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Spacer(),

                        // COPY SELECTED
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white),
                          onPressed: () {
                            HapticFeedback.lightImpact();

                            final selectedText = localMessages
                                .where((m) =>
                                    selectedMessages.contains(m["messageId"]))
                                .map((m) => m["text"])
                                .join("\n");

                            Clipboard.setData(
                                ClipboardData(text: selectedText));
                          },
                        ),

                        IconButton(
                          icon: const Icon(
                            Icons.forward,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();

                            // TODO:
                            // Open forward screen
                          },
                        ),

                        if (selectedMessages.length == 1)
                          IconButton(
                            icon: const Icon(
                              Icons.push_pin,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();

                              final id = selectedMessages.first;

                              // TODO

                              // await pinMessage(id);
                            },
                          ),

                        // DELETE SELECTED
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();

                            for (final id in selectedMessages) {
                              await _chatService.deleteMessage(
                                messageId: id,
                                senderId: currentUser.uid,
                                receiverId: widget.contactUserId,
                                type: "temporary",
                              );
                            }

                            setState(() {
                              selectedMessages.clear();
                              isSelectionMode = false;
                            });

                            await _loadLocalMessages();
                          },
                        ),

                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          color: Colors.white,
                          onSelected: (value) {
                            switch (value) {
                              case 'select_all':
                                setState(() {
                                  selectedMessages = localMessages
                                      .map((e) => e["messageId"].toString())
                                      .toList();
                                });

                                break;

                              case 'drag_select':
                                setState(() {
                                  dragSelectionEnabled = true;
                                });

                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'select_all',
                              child: Row(
                                children: [
                                  Icon(Icons.select_all),
                                  SizedBox(width: 10),
                                  Text("Select all"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'drag_select',
                              child: Row(
                                children: [
                                  Icon(Icons.swipe),
                                  SizedBox(width: 10),
                                  Text("Drag multi-select"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      // 🔹 BODY
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _dbHelper.getMessages(
                    currentUser.uid,
                    widget.contactUserId,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!;

                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!hasInitiallyScrolled && docs.isNotEmpty) {
                        hasInitiallyScrolled = true;

                        if (_itemScrollController.isAttached) {
                          _itemScrollController.scrollTo(
                            index: docs.length - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      }
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await _chatService.markMessagesAsSeen(
                        currentUserId: currentUser.uid,
                        otherUserId: widget.contactUserId,
                      );
                    });

                    return ScrollablePositionedList.builder(
                      reverse: !reverseChat,
                      itemCount: docs.length,
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      itemBuilder: (context, index) {
                        final msg = docs[index];

                        final messageId =
                            (msg["messageId"] ?? msg["id"] ?? "").toString();

                        final isMe = msg["senderId"] ==
                            FirebaseAuth.instance.currentUser!.uid;

                        final isDeleted = msg["isDeleted"] == 1;
                        final isEdited = msg["edited"] == 1;
                        final isRestored = msg["restored"] == 1;

                        final currDate = _toDate(msg["createdAt"]);

                        final prevDate = index > 0
                            ? _toDate(docs[index - 1]["createdAt"])
                            : null;

                        bool showDate = prevDate == null ||
                            prevDate.year != currDate.year ||
                            prevDate.month != currDate.month ||
                            prevDate.day != currDate.day;

                        List<Widget> widgets = [];

                        // 📅 DATE HEADER
                        if (showDate) {
                          widgets.add(
                            Center(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(getDateLabel(currDate)),
                              ),
                            ),
                          );
                        }

                        widgets.add(
                          StatefulBuilder(
                            builder: (context, setInnerState) {
                              return GestureDetector(
                                  // 📌 COPY
                                  onLongPress: () {
                                    if (isDeleted) return;
                                    HapticFeedback.heavyImpact();
                                    _removeKeyboardFocus();
                                    final isMe = msg["senderId"] ==
                                        FirebaseAuth.instance.currentUser!.uid;

                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) {
                                        return Container(
                                          margin: const EdgeInsets.all(12),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),

                                              const SizedBox(height: 15),
                                              // SELECT MODE (MULTI-SELECT)
                                              ListTile(
                                                leading: Icon(
                                                  isSelectionMode
                                                      ? Icons.check_box
                                                      : Icons
                                                          .check_box_outline_blank,
                                                  color: Colors.blue,
                                                ),
                                                title: const Text("Select"),
                                                onTap: () {
                                                  HapticFeedback
                                                      .selectionClick();
                                                  Navigator.pop(context);

                                                  setState(() {
                                                    isSelectionMode = true;

                                                    if (!selectedMessages
                                                        .contains(messageId)) {
                                                      selectedMessages
                                                          .add(messageId);
                                                    }
                                                  });
                                                },
                                              ),

                                              // COPY
                                              ListTile(
                                                leading: const Icon(Icons.copy),
                                                title: const Text("Copy"),
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                        text:
                                                            msg["text"] ?? ""),
                                                  );
                                                  Navigator.pop(context);
                                                  _removeKeyboardFocus();
                                                },
                                              ),

                                              // INFO
                                              ListTile(
                                                leading: const Icon(
                                                    Icons.info_outline),
                                                title: const Text("Info"),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  HapticFeedback.lightImpact();
                                                  _removeKeyboardFocus();
                                                },
                                              ),

                                              // DELETE (IMPORTANT PART)
                                              if (isMe)
                                                ListTile(
                                                  leading: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red),
                                                  title: const Text(
                                                    "Delete",
                                                    style: TextStyle(
                                                        color: Colors.red),
                                                  ),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    HapticFeedback
                                                        .lightImpact();
                                                    _removeKeyboardFocus();

                                                    // 🔥 DIRECTLY CALL DELETE FLOW
                                                    _handleDeleteMessage(
                                                        messageId);
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },

                                  // 📌 SWIPE REPLY
                                  onHorizontalDragUpdate: (details) {
                                    if (isDeleted) return;

                                    setState(() {
                                      final raw = swipeOffset[index] ?? 0;
                                      swipeOffset[index] =
                                          (raw + details.delta.dx)
                                              .clamp(-90, 90);
                                    });
                                  },
                                  onHorizontalDragEnd: (_) {
                                    final offset = swipeOffset[index] ?? 0;

                                    if (offset.abs() > 70) {
                                      HapticFeedback.mediumImpact();

                                      handleSwipeReply(
                                        msg["text"],
                                        messageId,
                                        index,
                                        docs,
                                      );
                                    }

                                    setState(() {
                                      swipeOffset[index] = 0;
                                    });
                                  },
                                  child: Transform.translate(
                                    offset: Offset(swipeOffset[index] ?? 0, 0),
                                    child: GestureDetector(
                                      onDoubleTap: isMe && !isDeleted
                                          ? () {
                                              setState(() {
                                                // toggle edit mode
                                                if (editingMessageId ==
                                                    messageId) {
                                                  editingMessageId = null;
                                                  editingIndex = null;
                                                  highlightedMessageId = null;
                                                  _controller.clear();
                                                  return;
                                                }

                                                editingMessageId = messageId;
                                                editingIndex = index;
                                                highlightedMessageId =
                                                    messageId;

                                                _controller.text =
                                                    msg["text"] ?? "";

                                                _controller.selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: _controller
                                                          .text.length),
                                                );
                                              });
                                            }
                                          : null,
                                      child: messageGlowWrapper(
                                        messageId: messageId,
                                        child: MessageBubble(
                                          msg: msg,
                                          isMe: isMe,
                                          isReplying: replyingToIndex == index,
                                          status: msg["status"] ?? "sent",
                                          isDeleted: isDeleted,
                                          deletedType: msg["deletedType"],
                                          userNames: userNames,
                                          isEdited: isEdited,
                                          isRestored: isRestored,
                                          isHighlighted:
                                              focusedMessageId == messageId,
                                          onRestore: () async {
                                            await _chatService.restoreMessage(
                                              messageId: messageId,
                                              senderId: currentUser.uid,
                                              receiverId: widget.contactUserId,
                                            );

                                            await _loadLocalMessages();

                                            if (mounted) {
                                              FocusScope.of(context).unfocus();
                                              setState(() {});
                                            }
                                          },
                                          onPermanentDelete: () async {
                                            await _chatService.deleteMessage(
                                              messageId: messageId,
                                              senderId: currentUser.uid,
                                              receiverId: widget.contactUserId,
                                              type: "permanent",
                                            );

                                            await _loadLocalMessages();

                                            if (mounted) {
                                              FocusScope.of(context).unfocus();
                                              setState(() {});
                                            }
                                          },
                                          onTap: () async {
                                            // 🟦 MULTI SELECT MODE ACTIVE
                                            if (isSelectionMode) {
                                              setState(() {
                                                if (selectedMessages
                                                    .contains(messageId)) {
                                                  selectedMessages
                                                      .remove(messageId);
                                                } else {
                                                  selectedMessages
                                                      .add(messageId);
                                                }

                                                // exit selection mode if empty
                                                if (selectedMessages.isEmpty) {
                                                  isSelectionMode = false;
                                                }
                                              });
                                              return;
                                            }

                                            // 🔵 NORMAL TAP LOGIC (your existing reply navigation)
                                            final targetId = msg["replyToId"];

                                            if (targetId != null) {
                                              final targetIndex =
                                                  docs.indexWhere(
                                                (d) => d["id"] == targetId,
                                              );

                                              if (targetIndex != -1) {
                                                setState(() {
                                                  focusedMessageId = targetId;
                                                });

                                                await _itemScrollController
                                                    .scrollTo(
                                                  index: targetIndex,
                                                  duration: const Duration(
                                                      milliseconds: 700),
                                                  curve: Curves.easeInOutCubic,
                                                  alignment: 0.3,
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ));
                            },
                          ),
                        );

                        return Container(
                          key: ValueKey(messageId),
                          child: Column(
                            children: widgets,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              if (replyingTo != null)
                Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 70,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 310, // 👈 adjust (200–300 feels good)
                      ),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 10),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 199, 224, 245),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: Colors.green,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                replyingTo?['text'] ?? "",
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color:
                                      const Color.fromARGB(255, 127, 127, 127),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  replyingTo = null;
                                  replyingToIndex = null;
                                });
                              },
                              child: Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // 🔹 INPUT FIELD
              SafeArea(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            TextField(
                              controller: _controller,
                              focusNode: _textFocusNode,
                              canRequestFocus: true,
                              onTap: () {
                                shouldAutoScroll = true;
                              },
                              minLines: 1,
                              maxLines: 5,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: "Type a message...",
                                filled: true,
                                fillColor: Color(0xFFF1F5F9),
                                contentPadding: EdgeInsets.only(
                                  right: 30,
                                  left: 12,
                                  top: 12,
                                  bottom: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                icon: Icon(
                                  Icons.open_in_full,
                                  size: 16,
                                  color: Color.fromARGB(221, 110, 110, 110),
                                ),
                                onPressed: openFullScreenInput,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          shouldAutoScroll = true;

                          await sendMessage();

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_itemScrollController.isAttached &&
                                localMessages.isNotEmpty) {
                              _itemScrollController.scrollTo(
                                index: localMessages.length - 1,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        },
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0XFF2563EB),
                          child:
                              Icon(Icons.send, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
