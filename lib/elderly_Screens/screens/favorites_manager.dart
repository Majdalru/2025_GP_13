import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FavoritesManager extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _userId;
  String? _role;

  final List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> get favorites => List.unmodifiable(_favorites);

  /// تحميل الفيفورت للـ Elderly فقط
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _userId = user.uid;

    final userDoc = await _db.collection("users").doc(_userId).get();
    _role = userDoc.data()?["role"] ?? "unknown";

    if (_role != "elderly") {

      _favorites.clear();
      notifyListeners();
      return;
    }

    final snap = await _db
        .collection("users")
        .doc(_userId)
        .collection("favorites")
        .orderBy("createdAt", descending: true)
        .get();

    _favorites
      ..clear()
      ..addAll(snap.docs.map((d) => d.data()));

    notifyListeners();
  }

  /// هل الصوت مضاف في الفيفورت؟
  bool isFavorite(String audioId) {
    return _favorites.any((f) => f["audioId"] == audioId);
  }

  /// إضافة/إزالة من الفيفورت
  Future<void> toggleFavorite(Map<String, dynamic> audio) async {
    if (_role != "elderly" || _userId == null) return;

    final favCol =
        _db.collection("users").doc(_userId).collection("favorites");

    final audioId = audio["audioId"];

    // هل موجود مسبقًا؟
    final existing = await favCol
        .where("audioId", isEqualTo: audioId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // إزالة
      await existing.docs.first.reference.delete();
      _favorites.removeWhere((f) => f["audioId"] == audioId);
    } else {
      // إضافة جديد
      final data = {
        "audioId": audio["audioId"],
        "title": audio["title"],
        "category": audio["category"],
        "fileName": audio["fileName"],
        "image": audio["image"],
         "type": audio["type"],   // audio | youtube
        "url": audio["url"],     // رابط اليوتيوب إن وجد
        "createdAt": FieldValue.serverTimestamp(),
      };
      await favCol.add(data);
      _favorites.add(data);
    }

    notifyListeners();
  }
}

final favoritesManager = FavoritesManager();
