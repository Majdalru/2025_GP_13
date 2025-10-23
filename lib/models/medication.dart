import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum DoseStatus { upcoming, takenOnTime, takenLate, missed }

class Medication {
  final String id; // Unique ID for the medication entry
  final String name;
  final List<String> days;
  final String? frequency;
  final List<TimeOfDay> times;
  final String? notes;
  final String addedBy; // UID of the user who added it
  final Timestamp createdAt;
  final Timestamp updatedAt;

  Medication({
    required this.id,
    required this.name,
    required this.days,
    this.frequency,
    required this.times,
    this.notes,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper to format TimeOfDay to a string "HH:mm" for Firestore
  static String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Helper to parse a string "HH:mm" from Firestore to TimeOfDay
  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // Converts a Medication object into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'days': days,
      'frequency': frequency,
      'times': times.map((time) => _formatTimeOfDay(time)).toList(),
      'notes': notes,
      'addedBy': addedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Creates a Medication object from a Firestore Map
  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Medication',
      days: List<String>.from(map['days'] ?? []),
      frequency: map['frequency'],
      times:
          (map['times'] as List<dynamic>?)
              ?.map((timeStr) => _parseTimeOfDay(timeStr.toString()))
              .toList() ??
          [],
      notes: map['notes'],
      addedBy: map['addedBy'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }
}
