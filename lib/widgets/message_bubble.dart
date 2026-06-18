import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class MessageBubble extends StatefulWidget {
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
  final Future<void> Function()? onRestore;
  final Future<void> Function()? onPermanentDelete;
  final String? deletedType;
  final Map<String, String>? userNames;
  final bool isRestored;

  const MessageBubble({
    super.key, // ✅ IMPORTANT (use super.key instead of Key? key)
    required this.msg,
    required this.isMe,
    required this.status,
    required this.isReplying,
    this.onDoubleTap,
    required this.isHighlighted,
    this.isEdited = false,
    this.isDeleted = false,
    this.userNames,
    this.isSwiped = false,
    this.onTap,
    this.onRestore,
    this.onPermanentDelete,
    this.deletedType,
    this.isRestored = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  Offset? tapPosition;
  late AnimationController controller;
  Animation<Color?>? colorAnimation;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15),
    );

    animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );

    colorAnimation = ColorTween(
      begin: widget.isMe ? const Color(0XFF2563EB) : Colors.white,
      end: widget.isMe ? const Color(0XFF60A5FA) : const Color(0xFFF1F5F9),
    ).animate(controller);

    controller.addListener(() {
      if (mounted) setState(() {});
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
    controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      tapPosition = details.localPosition;
    });

    // optional cleanup after animation
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          tapPosition = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDeleted) {
      String text = "";

      final senderId = widget.msg["senderId"]?.toString() ?? "";
      final senderName = widget.userNames?[senderId] ?? "Unknown";

      if (widget.deletedType == "temporary") {
        text = widget.isMe
            ? "You deleted message (Tap to recover)"
            : "$senderName deleted this message";
      } else {
        text = widget.isMe
            ? "You deleted this message permanently"
            : "$senderName deleted this message";
      }

      return GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          _removeKeyboardFocus();

// ❌ block if not sender OR not temporary
          if (!widget.isMe || widget.msg["deletedType"] != "temporary") return;

          final action = await showModalBottomSheet<String>(
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
                      "Deleted Message Options",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 🔵 RESTORE
                    if (widget.msg["deletedType"] == "temporary")
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, "restore");
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restore, color: Colors.blue, size: 20),
                              SizedBox(width: 10),
                              Text(
                                "Restore Message",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.msg["deletedType"] == "temporary")
                      const SizedBox(height: 10),

                    // 🔴 DELETE PERMANENTLY
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, "delete");
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Delete Permanently",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
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

          HapticFeedback.lightImpact();
          _removeKeyboardFocus();

          if (action == "restore") {
            _removeKeyboardFocus();
            widget.onRestore?.call();
            _removeKeyboardFocus();
          }

          if (action == "delete") {
            _removeKeyboardFocus();
            widget.onPermanentDelete?.call();
            _removeKeyboardFocus();
          }
        },
        child: Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? const Color(0xFFE5E7EB)
                  : (widget.isHighlighted
                      ? const Color.fromARGB(255, 235, 245, 255)
                      : const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                bottomRight: Radius.circular(widget.isMe ? 4 : 18),
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
                    const SizedBox(width: 6),
                    Flexible(
                      child: widget.isMe && widget.deletedType == "temporary"
                          ? RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color.fromARGB(255, 104, 104, 104),
                                  fontStyle: FontStyle.italic,
                                ),
                                children: [
                                  TextSpan(text: "You deleted message "),
                                  TextSpan(
                                    text: "(Tap to recover)",
                                    style: TextStyle(
                                      color:
                                          Colors.blueAccent, // or Colors.green
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              text,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: const Color.fromARGB(255, 97, 97, 97),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.msg["deletedTime"] ?? "",
                    style: TextStyle(
                      fontSize: 12,
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
    return InkWell(
      onTapDown: (_) {
        controller.forward(from: 0).then((_) {
          controller.reverse();
        });
      },
      splashColor: Colors.white.withOpacity(0.25),
      highlightColor: Colors.white.withOpacity(0.1),
      splashFactory: InkRipple.splashFactory,
      borderRadius: BorderRadius.circular(18),
      child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.96).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOut),
          ),
          child: Align(
            alignment:
                widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: colorAnimation?.value ??
                    (widget.isMe ? const Color(0XFF2563EB) : Colors.white),

                border: widget.isReplying
                    ? Border.all(
                        color: widget.isMe
                            ? Colors.white.withOpacity(0.6)
                            : Colors.blueAccent.withOpacity(0.4),
                        width: 1,
                      )
                    : null,

                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft:
                      widget.isMe ? Radius.circular(16) : Radius.circular(4),
                  bottomRight:
                      widget.isMe ? Radius.circular(4) : Radius.circular(16),
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
                  if (widget.isHighlighted)
                    BoxShadow(
                      color: const Color.fromARGB(255, 14, 14, 14)
                          .withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 2,
                      offset: Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (widget.msg["replyTo"] != null)
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                                color: widget.isReplying
                                    ? Colors.green
                                    : Colors.green.shade600,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.msg["replyTo"],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color:
                                      const Color.fromARGB(255, 127, 127, 127),
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
                    widget.msg["text"] ?? "",
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: widget.isMe
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      // ✅ EDITED LABEL FIRST
                      if (widget.isEdited)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            "edited",
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: widget.isMe ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        )
                      else if (widget.isRestored)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            "restored",
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: widget.isMe ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ),

                      // ✅ TIME
// ✅ TIME
// ✅ TIME (fixed alignment for sender bubble)
                      // ✅ TIME (fixed properly for both sides)
                      Align(
                        alignment: widget.isMe
                            ? Alignment.centerRight
                            : Alignment.centerRight,
                        child: Text(
                          widget.msg["localTime"] ?? "",
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isMe ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ),

                      if (widget.isMe) SizedBox(width: 4),

                      // ✅ STATUS DOTS
                      if (widget.isMe)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: List.generate(
                                (widget.status == "sent" ||
                                        widget.status == "pending")
                                    ? 1
                                    : 2, // 1 dot sent, 2 dots delivered/seen
                                (index) {
                                  Color color;
                                  if (widget.status == "pending") {
                                    color = Colors.orangeAccent;
                                  } else if (widget.status == "seen") {
                                    color = Colors.greenAccent;
                                  } else if (widget.status == "delivered") {
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
                            /* if (widget.status == "seen" && msg["seenAt"] != null)
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
          )),
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

class RipplePainter extends CustomPainter {
  final Offset tapPosition;
  final double progress;
  final Color color;

  RipplePainter(this.tapPosition, this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25 * (1 - progress))
      ..style = PaintingStyle.fill;

    final radius = progress * size.longestSide;

    canvas.drawCircle(tapPosition, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
