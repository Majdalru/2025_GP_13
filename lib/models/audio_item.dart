import 'package:cloud_firestore/cloud_firestore.dart';

class AudioItem {
  final String id;
  final String title;
  final String category;
  final String fileName;        // <-- مهم
  final String imageAsset;      // صورة حسب الكاتيجوري

  AudioItem({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.imageAsset,
  });

  // factory من Firestore
  factory AudioItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final category = data['category'] as String? ?? 'Story';

    return AudioItem(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      category: category,
      fileName: data['fileName'] as String? ?? '',    // <-- نقرأ fileName
      imageAsset: _imageForCategory(category),
    );
  }

  // دالة تساعدنا تختار الصورة حسب الكاتيجوري
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
