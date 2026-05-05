import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/services/chat_service.dart';
import 'package:talkie_new/widgets/message_bubble.dart';
import 'package:flutter/services.dart';

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
  Map<int, double> swipeOffset = {};
  String? highlightedMessageId;
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser!;

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

  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final messageText = _controller.text.trim();

    await _chatService.sendMessage(
      senderId: currentUser.uid,
      receiverId: widget.contactUserId,
      text: messageText,
      replyTo: replyingTo?["text"],
    );

    _controller.clear();

    setState(() {
      replyingTo = null;
      replyingToIndex = null;
      highlightedMessageId = null;
      // 🔥 RESET swipe UI after sending reply
      swipeOffset.clear();
    });

    Future.delayed(Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return "Today";
    if (msgDay == today.subtract(Duration(days: 1))) return "Yesterday";

    return "${date.day}/${date.month}/${date.year}"; // or use intl package for nicer formatting
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
                      stream: _chatService.getMessages(
                        currentUser.uid,
                        widget.contactUserId,
                      ),
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
                            final doc = docs[index];

                            final msg = doc.data() as Map<String, dynamic>;
                            final messageId = doc.id;

                            final bool isMe = msg["senderId"] ==
                                FirebaseAuth.instance.currentUser!.uid;

                            double _dragOffset = 0;

                            // Previous message date (or null if first message)
                            final prevRaw = index < docs.length - 1
                                ? (docs[index + 1].data()
                                    as Map<String, dynamic>)["createdAt"]
                                : null;

                            final prevDate = (prevRaw is Timestamp)
                                ? prevRaw.toDate()
                                : null;

                            final currDate =
                                (msg["createdAt"] as Timestamp?)?.toDate() ??
                                    DateTime.now();
                            final isDeleted = msg["isDeleted"] == 1;
                            final isEdited = msg["edited"] == 1;

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
                                  return LongPressDraggable<DocumentReference>(
                                      data: docs[index].reference,
                                      dragAnchorStrategy:
                                          pointerDragAnchorStrategy, // ✅ keeps finger aligned
                                      feedbackOffset:
                                          Offset(0, 0), // ✅ removes 8–10cm gap
                                      onDragStarted: () {
                                        setState(() {
                                          deletingIndex =
                                              index; // optional (or remove completely later)
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
                                        child: Transform.translate(
                                          offset: Offset(0,
                                              0), // 👈 removes weird offset gap
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.75,
                                            ),
                                            child: Opacity(
                                              opacity: 0.9,
                                              child: MessageBubble(
                                                msg: msg,
                                                isMe: isMe,
                                                isReplying: false,
                                                status: msg["status"] ?? "sent",
                                                isHighlighted: false,
                                                isEdited: isEdited,
                                                isDeleted: isDeleted,
                                                isSwiped:
                                                    (swipeOffset[index] ?? 0)
                                                            .abs() >
                                                        5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: GestureDetector(
                                        onHorizontalDragStart: (_) {
                                          swipeOffset[index] = 0;
                                        },
                                        onHorizontalDragUpdate: (details) {
                                          setState(() {
                                            final isMe = msg["senderId"] ==
                                                FirebaseAuth
                                                    .instance.currentUser!.uid;

                                            final raw = swipeOffset[index] ?? 0;

                                            // ✅ natural finger-follow (no inversion here)
                                            double next =
                                                raw + details.delta.dx;

                                            // ✅ flip ONLY display direction (WhatsApp style)
                                            swipeOffset[index] = isMe
                                                ? next.clamp(-80, 0)
                                                : next.clamp(0, 80);
                                          });
                                        },
                                        onHorizontalDragEnd: (_) {
                                          final offset =
                                              swipeOffset[index] ?? 0;

                                          setState(() {
                                            if (offset.abs() > 50) {
                                              replyingTo = msg;
                                              replyingToIndex = index;
                                            }

                                            swipeOffset[index] = 0;
                                          });
                                        },
                                        child: Transform.translate(
                                          offset: Offset(
                                            swipeOffset[index] ?? 0,
                                            0,
                                          ),
                                          child: AnimatedContainer(
                                            duration:
                                                Duration(milliseconds: 120),
                                            curve: Curves.easeOut,
                                            child: MessageBubble(
                                              msg: msg,
                                              isMe: isMe,
                                              status: msg["status"] ?? "sent",
                                              isReplying:
                                                  replyingToIndex == index,
                                              isHighlighted:
                                                  highlightedMessageId ==
                                                      messageId,
                                              isEdited: isEdited,
                                              isDeleted: isDeleted,
                                              isSwiped:
                                                  (swipeOffset[index] ?? 0)
                                                          .abs() >
                                                      5,
                                              onDoubleTap: isMe
                                                  ? () {
                                                      setState(() {
                                                        if (editingIndex ==
                                                            index) {
                                                          // 🔥 CANCEL EDIT MODE (NEW FEATURE YOU WANTED)
                                                          editingIndex = null;
                                                          highlightedMessageId =
                                                              null;
                                                          _controller.clear();
                                                          return;
                                                        }

                                                        editingIndex = index;
                                                        highlightedMessageId =
                                                            messageId;

                                                        _controller.text =
                                                            msg["text"] ?? "";
                                                        _controller.selection =
                                                            TextSelection
                                                                .fromPosition(
                                                          TextPosition(
                                                              offset:
                                                                  _controller
                                                                      .text
                                                                      .length),
                                                        );
                                                      });
                                                    }
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ));
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
                Positioned(
                  bottom: 80,
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
              child: DragTarget<DocumentReference>(
                onWillAccept: (data) {
                  HapticFeedback
                      .lightImpact(); // 👈 subtle vibration when hovering
                  return data != null;
                },
                onAccept: (DocumentReference ref) async {
                  HapticFeedback.heavyImpact(); // 👈 strong vibration on delete

                  await _chatService.deleteMessage(ref);

                  setState(() {
                    showTrash = false;
                    deletingIndex = null;
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final isActive = candidateData.isNotEmpty;

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    height: 100,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.red[600] : Colors.red[400],
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.6),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: Duration(milliseconds: 150),
                        scale: isActive ? 1.2 : 1.0,
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
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
