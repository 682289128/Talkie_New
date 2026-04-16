import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class _MessageState extends State<Message> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser!;

String getChatId(String user1, String user2) {
  List<String> ids = [user1, user2];
  ids.sort(); // ensures same order always
  return "${ids[0]}_${ids[1]}";
}

  Stream<QuerySnapshot> getMessagesStream() {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatId = getChatId(currentUser.uid, widget.contactUserId);

    return FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("date", descending: false)
        .snapshots();
  }

  Map<String, dynamic>?
      replyingTo; // keeps track of the message being replied to

  int?
      replyingToIndex; // tracks which message is being replied to for highlighting

  int? editingIndex; // tracks which message is being edited

  // Add these new state variables at the top
  int?
      deletingIndex; // tracks which message is currently being dragged for deletion
  Offset dragPosition = Offset.zero; // current position of the dragged message
  bool showTrash = false; // whether to show the trash bin

  bool reverseChat = true;

  // WhatsApp-style message data: text, isMe, time, sentStatus
  List<Map<String, dynamic>> messages = [
    {
      "text": "Hey 👋",
      "isMe": false,
      "time": "10:30 PM",
      "status": "received",
      "date": DateTime.now().subtract(Duration(days: 1))
    },
    {
      "text": "Hello bro!",
      "isMe": true,
      "time": "10:31 PM",
      "status": "sent",
      "date": DateTime.now().subtract(Duration(days: 1))
    },
    {
      "text": "How is Talkie going? 😎",
      "isMe": false,
      "time": "10:32 PM",
      "status": "received",
      "date": DateTime.now()
    },
    {
      "text":
          "Talkie is moving smoothly dude! Never seen something like this 😎",
      "isMe": true,
      "time": "10:32 PM",
      "status": "received",
      "date": DateTime.now()
    },
  ];

  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser!;
final chatId = getChatId(currentUser.uid, widget.contactUserId);

await FirebaseFirestore.instance
    .collection("chats")
    .doc(chatId)
    .set({
  "participants": [currentUser.uid, widget.contactUserId],
  "lastMessage": _controller.text.trim(),
  "updatedAt": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

    final messageData = {
      "text": _controller.text.trim(),
      "senderId": currentUser.uid,
      "receiverId": widget.contactUserId,
      "time": TimeOfDay.now().format(context),
      "status": "sent",
      "replyTo": replyingTo?["text"],
      "date": FieldValue.serverTimestamp(),
    };

    setState(() {
      if (editingIndex != null) {
        // Update existing message
        messages[editingIndex!] = {
          ...messages[editingIndex!],
          "text": _controller.text.trim(),
        };
        editingIndex = null; // reset after editing
      } else {
        // Add new message
        messages.add({
          "text": _controller.text.trim(),
          "isMe": true,
          "time": TimeOfDay.now().format(context),
          "status": "sent",
          "replyTo": replyingTo?["text"],
          "date": DateTime.now(),
        });
      }

      replyingTo = null; // reset reply
    });

    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add(messageData);

    _controller.clear();

    // Auto-scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Update status simulation for new messages
    if (editingIndex == null) {
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          messages.last["status"] = "delivered";
        });
      });

      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          messages.last["status"] = "read";
        });
      });
    }
  }

  String getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return "Today";
    if (msgDay == today.subtract(Duration(days: 1))) return "Yesterday";

    return "${date.month}/${date.day}/${date.year}"; // or use intl package for nicer formatting
  }

  void openFullScreenInput() {
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
    switch (status) {
      case "sent":
        baseColor = const Color.fromARGB(
          255,
          239,
          239,
          239,
        ); // visible on blue bubble
        break;
      case "delivered":
        baseColor = const Color.fromARGB(255, 255, 255, 255); // hand/thumb feel
        break;
      case "read":
        baseColor = Colors.greenAccent; // glowing eyes
        break;
      default:
        baseColor = Colors.white70;
    }

    int dotCount = status == "sent" ? 1 : 2;

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
            boxShadow: status == "read"
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
                          color: Colors.amberAccent.withOpacity(0.5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),

      // 🔹 APP BAR
      appBar: AppBar(
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
              child: widget.contactImage.isEmpty ? Icon(Icons.person) : null,
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

              // keep scroll position correct
              Future.delayed(Duration(milliseconds: 100), () {
                _scrollController.animateTo(
                  reverseChat
                      ? _scrollController.position.minScrollExtent
                      : _scrollController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              });
            },
          ),
        ],
        iconTheme: IconThemeData(color: Colors.black),
      ),

      // 🔹 BODY
      body: Stack(
        children: [
          Column(
            children: [
              // 🔹 MESSAGE LIST
              Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                      stream: getMessagesStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;

                        return ListView.builder(
                          reverse: !reverseChat,
                          controller: _scrollController,
                          itemCount: docs.length,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          itemBuilder: (context, index) {
                            final msg =
                                docs[index].data() as Map<String, dynamic>;
                            final bool isMe = msg["senderId"] ==
                                FirebaseAuth.instance.currentUser!.uid;

                            double _dragOffset = 0;

                            // Previous message date (or null if first message)
                            final prevRaw = index < docs.length - 1
                                ? (docs[index + 1].data()
                                    as Map<String, dynamic>)["date"]
                                : null;

                            final prevDate = (prevRaw is Timestamp)
                                ? prevRaw.toDate()
                                : null;

                            final currDate = (msg["date"] is Timestamp)
                                ? (msg["date"] as Timestamp).toDate()
                                : DateTime.now();

                            List<Widget> widgets = [];

                            // Add date separator if first message of a new day
                            if (prevDate == null ||
                                prevDate.day != currDate.day) {
                              widgets.add(
                                Center(
                                  child: Container(
                                    margin: EdgeInsets.symmetric(vertical: 10),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      getDateLabel(currDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Add the actual message bubble
                            widgets.add(
                              StatefulBuilder(
                                builder: (context, setInnerState) {
                                  return LongPressDraggable<int>(
                                    data: index,
                                    dragAnchorStrategy:
                                        pointerDragAnchorStrategy,
                                    onDragStarted: () {
                                      setState(() {
                                        deletingIndex = index;
                                        showTrash = true;
                                      });
                                    },
                                    onDraggableCanceled: (_, __) {
                                      setState(() {
                                        deletingIndex = null;
                                        showTrash = false;
                                      });
                                    },
                                    onDragEnd: (_) {
                                      setState(() {
                                        deletingIndex = null;
                                        showTrash = false;
                                      });
                                    },
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.8,
                                        child: Transform.translate(
                                          offset: Offset(_dragOffset, 0),
                                          child: Align(
                                            alignment: isMe
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Container(
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 4),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.75,
                                              ),
                                              decoration: BoxDecoration(
                                                color: replyingToIndex == index
                                                    ? Colors.grey[300]
                                                    : (isMe
                                                        ? Color(0XFF2563EB)
                                                        : Colors.white),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(16),
                                                  topRight: Radius.circular(16),
                                                  bottomLeft: isMe
                                                      ? Radius.circular(16)
                                                      : Radius.circular(4),
                                                  bottomRight: isMe
                                                      ? Radius.circular(4)
                                                      : Radius.circular(16),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(
                                                      0.05,
                                                    ),
                                                    blurRadius: 5,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: isMe
                                                    ? CrossAxisAlignment.end
                                                    : CrossAxisAlignment.start,
                                                children: [
                                                  if (msg["replyTo"] != null)
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6,
                                                      ),
                                                      margin: EdgeInsets.only(
                                                        bottom: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      constraints:
                                                          BoxConstraints(
                                                        maxWidth: MediaQuery.of(
                                                              context,
                                                            ).size.width *
                                                            0.65,
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Container(
                                                            width: 4,
                                                            margin:
                                                                EdgeInsets.only(
                                                              right: 6,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.green,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                2,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              msg["replyTo"],
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                              softWrap: true,
                                                              maxLines: 3,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  Text(
                                                    msg["text"] ?? "" ?? "",
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment: isMe
                                                        ? MainAxisAlignment.end
                                                        : MainAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        msg["time"] ?? "",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: isMe
                                                              ? Colors.white70
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                      if (isMe)
                                                        SizedBox(width: 4),
                                                      if (isMe)
                                                        messageStatusIcon(
                                                          msg["status"] ??
                                                              "sent",
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: GestureDetector(
                                      onDoubleTap: isMe
                                          ? () {
                                              setState(() {
                                                editingIndex = index;
                                                _controller.text =
                                                    msg["text"] ?? "";
                                                _controller.selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset:
                                                        _controller.text.length,
                                                  ),
                                                );
                                                Future.delayed(
                                                  Duration(milliseconds: 100),
                                                  () {
                                                    _scrollController.animateTo(
                                                      _scrollController.position
                                                          .maxScrollExtent,
                                                      duration: Duration(
                                                        milliseconds: 300,
                                                      ),
                                                      curve: Curves.easeOut,
                                                    );
                                                  },
                                                );
                                              });
                                            }
                                          : null,
                                      onHorizontalDragUpdate: (details) {
                                        if ((isMe && details.delta.dx < 0) ||
                                            (!isMe && details.delta.dx > 0)) {
                                          setInnerState(() {
                                            _dragOffset += details.delta.dx;
                                            if (_dragOffset.abs() > 30)
                                              _dragOffset =
                                                  _dragOffset.sign * 100;
                                          });
                                        }
                                      },
                                      onHorizontalDragEnd: (details) {
                                        if (_dragOffset.abs() > 20) {
                                          setState(() {
                                            replyingTo = msg;
                                            replyingToIndex = index;
                                          });
                                        }
                                        setInnerState(() {
                                          _dragOffset = 0;
                                        });
                                      },
                                      child: Transform.translate(
                                        offset: Offset(_dragOffset, 0),
                                        child: Align(
                                          alignment: isMe
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            margin: EdgeInsets.symmetric(
                                                vertical: 4),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.75,
                                            ),
                                            decoration: BoxDecoration(
                                              color: replyingToIndex == index
                                                  ? Colors.grey[300]
                                                  : (isMe
                                                      ? Color(0XFF2563EB)
                                                      : Colors.white),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                                bottomLeft: isMe
                                                    ? Radius.circular(16)
                                                    : Radius.circular(4),
                                                bottomRight: isMe
                                                    ? Radius.circular(4)
                                                    : Radius.circular(16),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: isMe
                                                  ? CrossAxisAlignment.end
                                                  : CrossAxisAlignment.start,
                                              children: [
                                                if (msg["replyTo"] != null)
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                    margin: EdgeInsets.only(
                                                        bottom: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxWidth: MediaQuery.of(
                                                            context,
                                                          ).size.width *
                                                          0.65,
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Container(
                                                          width: 4,
                                                          margin:
                                                              EdgeInsets.only(
                                                            right: 6,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.green,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              2,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            msg["replyTo"],
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                            softWrap: true,
                                                            maxLines: 3,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                Text(
                                                  msg["text"] ?? "",
                                                  style: TextStyle(
                                                    color: isMe
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment: isMe
                                                      ? MainAxisAlignment.end
                                                      : MainAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      msg["time"] ?? "",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isMe
                                                            ? Colors.white70
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                    if (isMe)
                                                      SizedBox(width: 4),
                                                    if (isMe)
                                                      messageStatusIcon(
                                                          msg["status"] ??
                                                              "sent"),
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
                              ),
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: widgets,
                            );
                          },
                        );
                      })),
              if (replyingTo != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Replying to: ${replyingTo!['text']}",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            replyingTo = null; // cancel reply
                            replyingToIndex = null;
                          });
                        },
                        child: Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              // 🔹 INPUT FIELD
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: EdgeInsets.only(bottom: 16),
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
                      onTap: sendMessage,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0XFF2563EB),
                        child: Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 🔹 Trash bin
          if (showTrash)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DragTarget<int>(
                onWillAccept: (data) => data != null,
                onAccept: (data) {
                  setState(() {
                    messages.removeAt(data);
                    if (replyingToIndex == data) {
                      replyingTo = null;
                      replyingToIndex = null;
                    }
                    if (editingIndex == data) editingIndex = null;

                    deletingIndex = null;
                    showTrash = false;
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    height: 100,
                    color: Colors.red[400],
                    child: Center(
                      child: Icon(Icons.delete, color: Colors.white, size: 36),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
