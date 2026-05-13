import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/services/chat_service.dart';
import 'package:talkie_new/widgets/message_bubble.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
  bool isNavigatingToReply = false;
  bool shouldAutoScroll = true;
  bool hasInitiallyScrolled = false;
  List<QueryDocumentSnapshot> currentDocs = [];
  final FocusNode _textFocusNode = FocusNode();

  String? focusedMessageId;
  Map<int, double> swipeOffset = {};
  String? highlightedMessageId;
  String? deletedHighlightedId;
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();

  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final currentUser = FirebaseAuth.instance.currentUser!;

  Map<String, dynamic>?
      replyingTo; // keeps track of the message being replied to

  int?
      replyingToIndex; // tracks which message is being replied to for highlighting

  int? editingIndex; // tracks which message is being edited
  String? editingMessageId; // 🔥 real message id for editing

  // Add these new state variables at the top
  int?
      deletingIndex; // tracks which message is currently being dragged for deletion
  Offset dragPosition = Offset.zero; // current position of the dragged message
  bool showTrash = false; // whether to show the trash bin

  bool reverseChat = true;

  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

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

    // 🟢 NORMAL SEND
    await _chatService.sendMessage(
      senderId: currentUser.uid,
      receiverId: widget.contactUserId,
      text: messageText,
      replyTo: replyingTo?["text"],
      replyToId: replyingTo?["messageId"],
    );

    _controller.clear();

    setState(() {
      replyingTo = null;
      replyingToIndex = null;
      highlightedMessageId = null;
      swipeOffset.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollToBottom(currentDocs);
    });

    Future.delayed(Duration(milliseconds: 500), () {
      shouldAutoScroll = false;
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

  Widget messageGlowWrapper({
    required String messageId,
    required Widget child,
  }) {
    final isFocused = focusedMessageId == messageId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 700), // smoother fade
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFocused
            ? const Color.fromARGB(255, 3, 141, 254).withOpacity(0.25)
            : Colors.transparent,
      ),
      child: child,
    );
  }

  void handleSwipeReply(
    String text,
    String messageId,
    int index,
    List<QueryDocumentSnapshot> docs,
  ) {
    replyingTo = {
      "text": text,
      "messageId": messageId,
    };
    replyingToIndex = index;

    // 🔥 haptic for BOTH sides
    HapticFeedback.selectionClick();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;

        FocusScope.of(context).unfocus();

        Future.delayed(const Duration(milliseconds: 30), () {
          if (!mounted) return;

          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) {
              FocusScope.of(context).requestFocus(_textFocusNode);
            }
          });
        });
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 120));

      _itemScrollController.scrollTo(
        index: docs.length - 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    });
  }

  void scrollToBottom(List docs) {
    if (!shouldAutoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (docs.isEmpty) return;

      await Future.delayed(const Duration(milliseconds: 100));

      if (!_itemScrollController.isAttached) return;

      try {
        await _itemScrollController.scrollTo(
          index: docs.length - 1,
          duration: const Duration(milliseconds: 300),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,

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
                        //<-here(on that opening curly brace)
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isNotEmpty) {
                          scrollToBottom(docs);
                        }
// 🔥 AUTO SCROLL TO LAST MESSAGE WHEN CHAT OPENS
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (docs.isNotEmpty && !hasInitiallyScrolled) {
                            hasInitiallyScrolled = true;

                            shouldAutoScroll = true;

                            scrollToBottom(docs);

                            Future.delayed(Duration(milliseconds: 500), () {
                              shouldAutoScroll = false;
                            });
                          }
                        });
                        return ScrollablePositionedList.builder(
                          shrinkWrap: false,
                          physics: const ClampingScrollPhysics(),
                          reverse: !reverseChat,
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          itemCount: docs.length,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];

                            final msg = doc.data() as Map<String, dynamic>;
                            msg["messageId"] = doc.id;
                            final messageId = doc.id;

                            final bool isMe = msg["senderId"] ==
                                FirebaseAuth.instance.currentUser!.uid;

// 🔥 Handle date correctly for both reverse modes
// 🔥 REAL reverse state from ListView
                            final bool isReversed = !reverseChat;

// 🔥 Compare correct neighboring message
                            Map<String, dynamic>? compareMsg;

                            if (isReversed) {
                              // bottom -> top
                              if (index < docs.length - 1) {
                                compareMsg = docs[index + 1].data()
                                    as Map<String, dynamic>;
                              }
                            } else {
                              // top -> bottom
                              if (index > 0) {
                                compareMsg = docs[index - 1].data()
                                    as Map<String, dynamic>;
                              }
                            }

                            final prevRaw = compareMsg?["createdAt"];

                            final prevDate = (prevRaw is Timestamp)
                                ? prevRaw.toDate()
                                : null;

                            final currDate = (msg["createdAt"] is Timestamp)
                                ? (msg["createdAt"] as Timestamp).toDate()
                                : DateTime.fromMillisecondsSinceEpoch(0);

                            final isDeleted = msg["isDeleted"] == 1;
                            final isEdited = msg["edited"] == 1;

                            List<Widget> widgets = [];

// 🔥 TRUE date comparison
                            bool isDifferentDate = prevDate == null ||
                                prevDate.year != currDate.year ||
                                prevDate.month != currDate.month ||
                                prevDate.day != currDate.day;

// 🔥 DATE WIDGET
                            Widget dateWidget = Center(
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
                            );

// ✅ ALWAYS PLACE DATE ABOVE FIRST MESSAGE OF THAT DAY
                            if (isDifferentDate) {
                              widgets.add(dateWidget);
                            }

                            // Add the actual message bubble
                            widgets.add(
                              StatefulBuilder(
                                builder: (context, setInnerState) {
                                  if (!isMe) {
                                    return GestureDetector(
                                      onLongPress: () {
                                        // ❌ BLOCK COPY IF MESSAGE IS DELETED
                                        if (isDeleted) return;

                                        HapticFeedback.heavyImpact();

                                        Clipboard.setData(ClipboardData(
                                            text: msg["text"] ?? ""));

                                        HapticFeedback.selectionClick();
                                      },

                                      // 🔥 ADD SWIPE BACK FOR RECEIVER MESSAGES
                                      onHorizontalDragUpdate: (details) {
                                        if (isDeleted) return;
                                        setState(() {
                                          final raw = swipeOffset[index] ?? 0;
                                          double next = raw + details.delta.dx;

                                          swipeOffset[index] =
                                              next.clamp(0, 80);
                                        });
                                      },

                                      onHorizontalDragEnd: (_) {
                                        if (isDeleted) return;
                                        final offset = swipeOffset[index] ?? 0;

                                        setState(() {
                                          if (offset.abs() > 50) {
                                            handleSwipeReply(msg["text"],
                                                messageId, index, docs);
                                          }

                                          swipeOffset[index] = 0;
                                        });
                                      },

                                      child: Transform.translate(
                                        offset:
                                            Offset(swipeOffset[index] ?? 0, 0),
                                        child: messageGlowWrapper(
                                          messageId: messageId,
                                          child: MessageBubble(
                                            msg: msg,
                                            isMe: isMe,
                                            status: msg["status"] ?? "sent",
                                            isReplying:
                                                replyingToIndex == index,

                                            // 🔥 ORIGINAL EDIT HIGHLIGHT
                                            isHighlighted:
                                                highlightedMessageId ==
                                                        messageId ||
                                                    focusedMessageId ==
                                                        messageId,

                                            isEdited: isEdited,
                                            isDeleted: isDeleted,
                                            deletedType: msg["deletedType"],

                                            // 🔥 NEW TAP REPLY FEATURE
                                            onTap: () async {
                                              final targetId = msg["replyToId"];

                                              if (targetId != null) {
                                                final targetIndex =
                                                    docs.indexWhere((d) =>
                                                        d.id == targetId);

                                                if (targetIndex != -1) {
                                                  setState(() {
                                                    focusedMessageId = targetId;
                                                  });

                                                  await _itemScrollController
                                                      .scrollTo(
                                                    index: targetIndex,
                                                    duration: Duration(
                                                        milliseconds: 500),
                                                    curve: Curves.easeInOut,
                                                    alignment: 0.3,
                                                  );

                                                  Future.delayed(
                                                      Duration(seconds: 2), () {
                                                    if (mounted) {
                                                      setState(() {
                                                        focusedMessageId = null;
                                                      });
                                                    }
                                                  });
                                                }

                                                return;
                                              }

                                              if (isDeleted &&
                                                  msg["deletedType"] ==
                                                      "temporary") {
                                                await _chatService
                                                    .restoreMessage(
                                                  messageId: messageId,
                                                  senderId: currentUser.uid,
                                                  receiverId:
                                                      widget.contactUserId,
                                                );
                                              }
                                            },

                                            // 🔥 EXISTING RESTORE LOGIC
                                            isSwiped: (swipeOffset[index] ?? 0)
                                                    .abs() >
                                                5,

                                            onDoubleTap: isMe
                                                ? () {
                                                    setState(() {
                                                      if (editingIndex ==
                                                          index) {
                                                        editingIndex = null;
                                                        editingMessageId = null;
                                                        highlightedMessageId =
                                                            null;
                                                        _controller.clear();
                                                        return;
                                                      }

                                                      editingIndex = index;
                                                      editingMessageId =
                                                          messageId;
                                                      highlightedMessageId =
                                                          messageId;

                                                      _controller.text =
                                                          msg["text"] ?? "";

                                                      _controller.selection =
                                                          TextSelection
                                                              .fromPosition(
                                                        TextPosition(
                                                          offset: _controller
                                                              .text.length,
                                                        ),
                                                      );
                                                    });
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  if (isDeleted) {
                                    return GestureDetector(
                                      onTap: () async {
                                        if (msg["deletedType"] == "permanent") {
                                          return; // ❌ block popup completely
                                        }

                                        final action =
                                            await showModalBottomSheet<String>(
                                          context: context,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(18)),
                                          ),
                                          builder: (context) {
                                            return Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Title
                                                  Text(
                                                    "Deleted Message Options",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),

                                                  SizedBox(height: 18),

                                                  // 🔵 RESTORE (ONLY IF TEMPORARY)
                                                  if (msg["deletedType"] ==
                                                      "temporary")
                                                    InkWell(
                                                      onTap: () =>
                                                          Navigator.pop(context,
                                                              "restore"),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: Container(
                                                        width: double.infinity,
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                vertical: 14,
                                                                horizontal: 12),
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                              color: Colors.blue
                                                                  .shade200,
                                                              width: 1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(Icons.restore,
                                                                color:
                                                                    Colors.blue,
                                                                size: 20),
                                                            SizedBox(width: 10),
                                                            Text(
                                                              "Restore Message",
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .blue
                                                                    .shade700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),

                                                  if (msg["deletedType"] ==
                                                      "temporary")
                                                    SizedBox(height: 10),

                                                  // 🔴 PERMANENT DELETE
                                                  InkWell(
                                                    onTap: () => Navigator.pop(
                                                        context, "delete"),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 14,
                                                              horizontal: 12),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            color: Colors
                                                                .red.shade200,
                                                            width: 1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color: Colors.red,
                                                              size: 20),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            "Delete Permanently",
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .red.shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),

                                                  SizedBox(height: 6),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                        setState(() {
                                          deletedHighlightedId = null;
                                        });
                                        if (action == "restore") {
                                          await _chatService.restoreMessage(
                                            messageId: messageId,
                                            senderId: currentUser.uid,
                                            receiverId: widget.contactUserId,
                                          );
                                        }

                                        if (action == "delete") {
                                          await _chatService.deleteMessage(
                                            messageId: messageId,
                                            senderId: currentUser.uid,
                                            receiverId: widget.contactUserId,
                                            type: "permanent",
                                          );
                                        }
                                      },
                                      child: MessageBubble(
                                        msg: msg,
                                        isMe: isMe,
                                        status: msg["status"] ?? "sent",
                                        isDeleted: isDeleted,
                                        deletedType: msg["deletedType"],

                                        // ❌ EVERYTHING ELSE DISABLED
                                        isSwiped: false,
                                        isReplying: false,
                                        isHighlighted: false,
                                        isEdited: false,
                                      ),
                                    );
                                  }

                                  return LongPressDraggable<DocumentReference>(
                                      data: docs[index].reference,
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
                                      onDragEnd: (details) async {
                                        setState(() {
                                          deletingIndex = null;
                                          showTrash = false;
                                        });

                                        // If dropped on trash zone, show dialog
                                        if (details.wasAccepted) return;

                                        // OPTIONAL SAFETY: only trigger if near bottom (trash area)
                                        final screenHeight =
                                            MediaQuery.of(context).size.height;
                                        final dropY = details.offset.dy;

                                        if (dropY > screenHeight - 120) {
                                          final result =
                                              await showModalBottomSheet<
                                                  String>(
                                            context: context,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                      top: Radius.circular(18)),
                                            ),
                                            builder: (context) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "Delete message?",
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    SizedBox(height: 10),

                                                    Text(
                                                      "Choose how you want to delete this message",
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          color: Colors.grey),
                                                    ),

                                                    SizedBox(height: 20),

                                                    // 🔴 Permanent delete
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                        onPressed: () {
                                                          Navigator.pop(context,
                                                              "permanent");
                                                        },
                                                        child: Text(
                                                            "Delete for everyone (Permanent)"),
                                                      ),
                                                    ),

                                                    SizedBox(height: 10),

                                                    // 🟠 Temporary delete
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: OutlinedButton(
                                                        onPressed: () {
                                                          Navigator.pop(context,
                                                              "temporary");
                                                        },
                                                        child: Text(
                                                            "Delete for me (Recoverable)"),
                                                      ),
                                                    ),

                                                    SizedBox(height: 10),
                                                  ],
                                                ),
                                              );
                                            },
                                          );

                                          if (result != null) {
                                            await _chatService.deleteMessage(
                                              messageId: messageId,
                                              senderId: currentUser.uid,
                                              receiverId: widget.contactUserId,
                                              type: result,
                                            );
                                          }
                                        }
                                      },
                                      feedback: Builder(
                                        builder: (context) {
                                          final screenWidth =
                                              MediaQuery.of(context).size.width;

                                          return Material(
                                            color: Colors.transparent,
                                            child: Transform.translate(
                                              offset:
                                                  Offset(screenWidth * 0.25, 0),
                                              // 👈 pushes bubble toward right side intentionally
                                              child: Opacity(
                                                opacity: 0.95,
                                                child: MessageBubble(
                                                  msg: msg,
                                                  isMe: isMe,
                                                  isReplying: false,
                                                  status:
                                                      msg["status"] ?? "sent",
                                                  isHighlighted: false,
                                                  isEdited: isEdited,
                                                  isDeleted: isDeleted,
                                                  deletedType:
                                                      msg["deletedType"],
                                                  isSwiped: false,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
                                              handleSwipeReply(msg["text"],
                                                  messageId, index, docs);
                                            }

                                            swipeOffset[index] = 0;
                                          });
                                        },
                                        child: Transform.translate(
                                          offset: Offset(
                                            swipeOffset[index] ?? 0,
                                            0,
                                          ),
                                          child: messageGlowWrapper(
                                            messageId: messageId,
                                            child: MessageBubble(
                                              msg: msg,
                                              isMe: isMe,
                                              status: msg["status"] ?? "sent",
                                              isReplying:
                                                  replyingToIndex == index,
                                              isHighlighted:
                                                  highlightedMessageId ==
                                                          messageId ||
                                                      focusedMessageId ==
                                                          messageId,
                                              isEdited: isEdited,
                                              isDeleted: isDeleted,
                                              deletedType: msg["deletedType"],
                                              onTap: () async {
                                                // 🔥 REPLY NAVIGATION

                                                final targetId =
                                                    msg["replyToId"];

                                                if (targetId != null) {
                                                  final targetIndex =
                                                      docs.indexWhere((d) =>
                                                          d.id == targetId);

                                                  if (targetIndex != -1) {
                                                    setState(() {
                                                      focusedMessageId =
                                                          targetId;
                                                    });

                                                    await _itemScrollController
                                                        .scrollTo(
                                                      index: targetIndex,
                                                      duration: Duration(
                                                          milliseconds: 500),
                                                      curve: Curves.easeInOut,
                                                      alignment: 0.3,
                                                    );

                                                    Future.delayed(
                                                        Duration(seconds: 2),
                                                        () {
                                                      if (mounted) {
                                                        setState(() {
                                                          focusedMessageId =
                                                              null;
                                                        });
                                                      }
                                                    });
                                                  }

                                                  return;
                                                }

                                                // 🔥 RESTORE TEMP MESSAGE
                                                if (isDeleted &&
                                                    msg["deletedType"] ==
                                                        "temporary") {
                                                  await _chatService
                                                      .restoreMessage(
                                                    messageId: messageId,
                                                    senderId: currentUser.uid,
                                                    receiverId:
                                                        widget.contactUserId,
                                                  );
                                                }
                                              },
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
                                                          editingMessageId =
                                                              null; // 🔥 reset
                                                          highlightedMessageId =
                                                              null;
                                                          _controller.clear();
                                                          return;
                                                        }

                                                        editingIndex = index;
                                                        editingMessageId =
                                                            messageId; // 🔥 important
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

                            return Container(
                              key: ValueKey(messageId),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: widgets,
                              ),
                            );
                          },
                        );
                      })),
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

                          sendMessage();

                          final docs = await _getCurrentDocs();

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            scrollToBottom(docs);
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
                  HapticFeedback.heavyImpact();

                  final result = await showModalBottomSheet<String>(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title
                              Text(
                                "Delete message",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),

                              SizedBox(height: 8),

                              // Subtitle
                              Text(
                                "Choose how you want to delete this message",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              SizedBox(height: 20),

                              // 🟦 TEMPORARY DELETE (PRIMARY)
                              InkWell(
                                onTap: () =>
                                    Navigator.pop(context, "temporary"),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color:
                                            Color(0XFF2563EB).withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.restore,
                                          color: Color(0XFF2563EB), size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Temporary (can be restored)",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0XFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 10),

                              // ⚪ PERMANENT DELETE
                              InkWell(
                                onTap: () =>
                                    Navigator.pop(context, "permanent"),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.red.shade300),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Permanent (Cannot be restored)",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 12),
                            ],
                          ),
                        );
                      });

                  if (result != null) {
                    await _chatService.deleteMessage(
                      messageId: ref.id,
                      senderId: currentUser.uid,
                      receiverId: widget.contactUserId,
                      type: result,
                    );
                  }

                  setState(() {
                    showTrash = false;
                    deletingIndex = null;
                  });

                  // 🔥 NEXT STEP WILL GO HERE (BACKEND LOGIC)
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
