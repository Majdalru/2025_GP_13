import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/shared_item.dart';

class SharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload file to Firebase Storage
  Future<String?> uploadFile({
    required File file,
    required String elderlyId,
    required String fileName,
    required SharedItemType type,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('shared_media/$elderlyId/${type.name}/$fileName');
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  // Save metadata to Firestore
  Future<void> shareItem({
    required SharedItem item,
    required String elderlyId,
  }) async {
    try {
      // We store items in a subcollection for the elderly user
      await _firestore
          .collection('shared_content')
          .doc(elderlyId)
          .collection('items')
          .doc(item.id)
          .set(item.toMap());
      
      debugPrint('Shared item saved to Firestore: ${item.id}');
    } catch (e) {
      debugPrint('Error sharing item: $e');
      rethrow;
    }
  }
  
  // Method to get shared items stream
  Stream<List<SharedItem>> getSharedItems(String elderlyId) {
    return _firestore
        .collection('shared_content')
        .doc(elderlyId)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SharedItem.fromMap(doc.data())).toList();
    });
  }
}
