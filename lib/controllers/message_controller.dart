class MessageController {
  Map<String, dynamic>? replyingTo;
  int? replyingIndex;
  int? editingIndex;

  void startReply(Map<String, dynamic> msg, int index) {
    replyingTo = msg;
    replyingIndex = index;
  }

  void cancelReply() {
    replyingTo = null;
    replyingIndex = null;
  }
}