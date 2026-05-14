import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageBubble extends StatelessWidget {
  final String status;
  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isReplying;
  final Function()? onDoubleTap;
  final bool isHighlighted;
  final bool isEdited;
  final bool isDeleted;
  final bool isSwiped;
  final Function()? onTap;
  final String? deletedType;

  const MessageBubble({
    Key? key,
    required this.msg,
    required this.isMe,
    required this.status,
    required this.isReplying,
    this.onDoubleTap,
    required this.isHighlighted,
    this.isEdited = false,
    this.isDeleted = false,
    this.isSwiped = false,
    this.onTap,
    this.deletedType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isDeleted) {
      String text = "";

      if (deletedType == "temporary") {
        text = isMe
            ? "You deleted this message (tap to recover)"
            : "${msg["senderName"] ?? "Unknown"} deleted this message";
      } else {
        text = isMe
            ? "You deleted this message permanently"
            : "${msg["senderName"] ?? "Unknown"} deleted this message";
      }

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? const Color.fromARGB(255, 187, 222, 251)
                  : (isMe ? Color(0xFFE3F2FD) : Colors.grey.shade200),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    msg["deletedTime"] ?? "",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe ? const Color(0XFF2563EB) : Colors.white,

            border: isReplying
                ? Border.all(
                    color: isMe
                        ? Colors.white.withOpacity(0.6)
                        : Colors.blueAccent.withOpacity(0.4),
                    width: 1,
                  )
                : null,

            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
              bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
            ),

            // ❌ remove border completely

            boxShadow: [
              // base shadow (always there)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),

              // 🔥 highlight glow (only when selected)
              if (isHighlighted)
                BoxShadow(
                  color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg["replyTo"] != null)
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: EdgeInsets.only(
                      bottom: 4,
                      left: 0,
                      right: 0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 192, 223, 248),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: Colors.green,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          margin: EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: isReplying
                                ? Colors.green
                                : Colors.green.shade600,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            msg["replyTo"],
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: const Color.fromARGB(255, 127, 127, 127),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // ✅ MESSAGE TEXT
              Text(
                msg["text"] ?? "",
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  // ✅ EDITED LABEL FIRST
                  if (isEdited)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        "edited.",
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isMe ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ),

                  // ✅ TIME
// ✅ TIME
// ✅ TIME (fixed alignment for sender bubble)
                  // ✅ TIME (fixed properly for both sides)
                  Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerRight,
                    child: Text(
                      msg["localTime"] ?? "",
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ),

                  if (isMe) SizedBox(width: 4),

                  // ✅ STATUS DOTS
                  if (isMe)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: List.generate(
                            (status == "sent" || status == "pending")
                                ? 1
                                : 2, // 1 dot sent, 2 dots delivered/seen
                            (index) {
                              Color color;
                              if (status == "pending") {
                                color = Colors.orangeAccent;
                              } else if (status == "seen") {
                                color = Colors.greenAccent;
                              } else if (status == "delivered") {
                                color = Colors.white;
                              } else {
                                color = Colors.white70;
                              }

                              return Container(
                                margin: EdgeInsets.only(left: 3),
                                height: 9,
                                width: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                        ),

                        // ✅ FIXED: Seen time (OUTSIDE loop)
                        /* if (status == "seen" && msg["seenAt"] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              _formatSeenTime(msg["seenAt"]),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),*/
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSeenTime(dynamic timestamp) {
    try {
      DateTime time;

      if (timestamp is Timestamp) {
        time = timestamp.toDate();
      } else {
        return "";
      }

      int hour = time.hour;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? "PM" : "AM";

      hour = hour % 12;
      if (hour == 0) hour = 12;

      return "$hour:$minute $period";
    } catch (e) {
      return "";
    }
  }
}
