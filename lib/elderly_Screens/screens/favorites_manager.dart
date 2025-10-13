import 'package:flutter/material.dart';

class FavoritesManager extends ChangeNotifier {
  final List<Map<String, String>> _favorites = [];

  List<Map<String, String>> get favorites => _favorites;

  bool isFavorite(String title) {
    return _favorites.any((item) => item["title"] == title);
  }

  void toggleFavorite(Map<String, String> item) {
    final existingIndex =
        _favorites.indexWhere((fav) => fav["title"] == item["title"]);
    if (existingIndex >= 0) {
      _favorites.removeAt(existingIndex);
    } else {
      _favorites.add(item);
    }
    notifyListeners();
  }
}

final favoritesManager = FavoritesManager();
