import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum DoseStatus { upcoming, takenOnTime, takenLate, missed }

class Medication {
  final String id;
  final String name;
  final String? doseForm; // ← NEW: e.g. "Tablet", "Syrup", "Cream"
  final String? doseStrength; // ← NEW: e.g. "500 mg", "0.5%", "10 ml"
  final List<String> days;
  final String? frequency;
  final List<TimeOfDay> times;
  final String? notes;
  final String addedBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? endDate;

  Medication({
    required this.id,
    required this.name,
    this.doseForm,
    this.doseStrength,
    required this.days,
    this.frequency,
    required this.times,
    this.notes,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
    this.endDate,
  });

  static String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (doseForm != null) 'doseForm': doseForm,
      if (doseStrength != null) 'doseStrength': doseStrength,
      'days': days,
      'frequency': frequency,
      'times': times.map((time) => _formatTimeOfDay(time)).toList(),
      'notes': notes,
      'addedBy': addedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (endDate != null) 'endDate': endDate,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Medication',
      doseForm: map['doseForm'],
      doseStrength: map['doseStrength'],
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
      endDate: map['endDate'] as Timestamp?,
    );
  }
}
