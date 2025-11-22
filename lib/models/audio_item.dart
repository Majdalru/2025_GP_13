import 'package:cloud_firestore/cloud_firestore.dart';

class AudioItem {
  final String id;
  final String title;
  final String category;
  final String fileName;
  final String tag;            //  
  final String imageAsset;

  AudioItem({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.tag,         //  
    required this.imageAsset,
  });

  factory AudioItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final category = data['category'] as String? ?? 'Story';

    return AudioItem(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      category: category,
      fileName: data['fileName'] as String? ?? '',
      tag: data['tag'] as String? ?? 'All',     //  نقرأ tag من Firestore
      imageAsset: _imageForCategory(category),
    );
  }

  static String _imageForCategory(String category) {
    switch (category) {
      case 'Story':
        return 'assets/books.jpeg';
      case 'Quran':
        return 'assets/Quran_cover.jpg';
      case 'Health':
        return 'assets/Health.png';
      case 'Caregiver':
        return 'assets/gift.jpg';
      default:
        return 'assets/audio.jpg';
    }
  }
}
