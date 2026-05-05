import 'package:flutter/material.dart';

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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            color: isReplying
                ? const Color.fromARGB(255, 217, 237, 253) //->here
                : isSwiped
                    ? const Color.fromARGB(255, 217, 237, 253)
                    : (isMe ? Color(0XFF2563EB) : Colors.white),

            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
              bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
            ),

            // ❌ remove border completely
            border: null,

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
                Container(
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
                          color:
                              isReplying ? Colors.green : Colors.green.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          msg["replyTo"],
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isDeleted)
                Text(
                  "This message was deleted",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: isReplying
                            ? Colors.black // ✅ persistent after swipe
                            : isSwiped
                                ? Colors.black // optional: while swiping
                                : (isMe ? Colors.white : Colors.black87),
                        fontSize: 14,
                      ),
                    ),

                    // 👇 EDIT LABEL goes directly UNDER text
                    if (isEdited)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "edited",
                          style: TextStyle(
                            fontSize: 10,
                            color: isReplying
                                ? Colors.black54
                                : isSwiped
                                    ? Colors.black54
                                    : (isMe ? Colors.white70 : Colors.grey),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    msg["localTime"] ?? "",
                    style: TextStyle(
                      fontSize: 10,
                      color: isReplying
                          ? Colors.black54
                          : isSwiped
                              ? Colors.black54
                              : (isMe ? Colors.white70 : Colors.grey),
                    ),
                  ),
                  if (isMe) SizedBox(width: 4),
                  if (isMe)
                    Row(
                      children: List.generate(
                        status == "delivered" ? 1 : 2,
                        (index) {
                          Color color;

                          if (status == "seen") {
                            color = Colors.greenAccent;
                          } else if (status == "delivered") {
                            color = Colors.white;
                          } else {
                            color = Colors.white70; // sent
                          }

                          return Container(
                            margin: EdgeInsets.only(left: 3),
                            height: 9,
                            width: 9,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: status == "seen"
                                  ? [
                                      BoxShadow(
                                        color: const Color.fromARGB(
                                                255, 255, 255, 255)
                                            .withOpacity(0.7),
                                        blurRadius: 10,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : [],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
