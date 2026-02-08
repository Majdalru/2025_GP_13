import 'package:cloud_firestore/cloud_firestore.dart';

enum SharedItemType { video, audio, message }

class SharedItem {
  final String id;
  final SharedItemType type;
  final String title;
  final String? content; // For text messages or descriptions
  final String? url; // For media files (video/audio)
  final String senderId;
  final DateTime timestamp;
  final String? fileName;

  SharedItem({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    this.url,
    required this.senderId,
    required this.timestamp,
    this.fileName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name, // 'video', 'audio', 'message'
      'title': title,
      'content': content,
      'url': url,
      'senderId': senderId,
      'timestamp': Timestamp.fromDate(timestamp),
      'fileName': fileName,
    };
  }

  factory SharedItem.fromMap(Map<String, dynamic> map) {
    return SharedItem(
      id: map['id'] ?? '',
      type: SharedItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SharedItemType.message,
      ),
      title: map['title'] ?? '',
      content: map['content'],
      url: map['url'],
      senderId: map['senderId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      fileName: map['fileName'],
    );
  }
}
