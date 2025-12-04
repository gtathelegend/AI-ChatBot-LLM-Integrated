class Attachment {
  final String name;
  final String path;
  final String mimeType;

  Attachment({
    required this.name,
    required this.path,
    required this.mimeType,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Attachment> attachments;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachments = const [],
  });
}
