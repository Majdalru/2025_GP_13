import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/medication.dart';
import '../../services/medication_scheduler.dart';
import '../../services/medication_scan_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

// --- Main Stateful Widget for AddMedScreen ---
class AddMedScreen extends StatefulWidget {
  final Medication? medicationToEdit;
  final String elderlyId; // Pass the elderly user's ID

  const AddMedScreen({
    super.key,
    this.medicationToEdit,
    required this.elderlyId,
  });

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

class _AddMedScreenState extends State<AddMedScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late final bool _isEditing;

  // Form data
  String? _medicationName;
  String? _doseForm; // ← NEW
  String? _doseStrength; // ← NEW
  int? _durationDays; // ← NEW
  DateTime? _customEndDate; // ← NEW
  List<String> _selectedDays = [];
  String? _frequency;
  List<TimeOfDay?> _selectedTimes = [];
  String? _notes;

  // Scan
  final ImagePicker _picker = ImagePicker();
  final MedicationScanService _scanService = MedicationScanService();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.medicationToEdit != null;

    if (_isEditing) {
      final med = widget.medicationToEdit!;
      _medicationName = med.name;
      _doseForm = med.doseForm; // ← NEW
      _doseStrength = med.doseStrength; // ← NEW
      _selectedDays = List.from(med.days);
      _frequency = med.frequency;
      // Ensure selectedTimes is mutable
      _selectedTimes = List<TimeOfDay?>.from(med.times);
      _notes = med.notes;

      // ← NEW: restore duration
      if (med.endDate != null) {
        _customEndDate = med.endDate!.toDate();
        final diff = _customEndDate!.difference(med.createdAt.toDate()).inDays;
        if ([3, 5, 7, 10, 14, 30].contains(diff)) {
          _durationDays = diff;
        } else {
          _durationDays = -1;
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Timestamp? _computeEndDate() {
    // Find the latest dose time, fallback to 23:59 if no times set
    int endHour = 23;
    int endMinute = 59;

    final times = _selectedTimes.whereType<TimeOfDay>().toList();
    if (times.isNotEmpty) {
      times.sort((a, b) {
        final aMin = a.hour * 60 + a.minute;
        final bMin = b.hour * 60 + b.minute;
        return aMin.compareTo(bMin);
      });
      endHour = times.last.hour;
      endMinute = times.last.minute;
    }

    if (_customEndDate != null) {
      return Timestamp.fromDate(
        DateTime(
          _customEndDate!.year,
          _customEndDate!.month,
          _customEndDate!.day,
          endHour,
          endMinute,
          0,
        ),
      );
    }
    if (_durationDays != null && _durationDays! > 0) {
      final startDate = _isEditing
          ? widget.medicationToEdit!.createdAt.toDate()
          : DateTime.now();
      final end = startDate.add(Duration(days: _durationDays!));
      return Timestamp.fromDate(
        DateTime(end.year, end.month, end.day, endHour, endMinute, 0),
      );
    }
    return null;
  }

  // --- Firestore Logic ---
  Future<void> _saveMedication() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save.')),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyId);
    final Timestamp? endDate = _computeEndDate(); // ← NEW

    if (_isEditing) {
      // --- UPDATE LOGIC ---
      final updatedMed = Medication(
        id: widget.medicationToEdit!.id,
        name: _medicationName ?? 'Unnamed',
        doseForm: _doseForm,
        doseStrength: _doseStrength,
        days: _selectedDays,
        frequency: _frequency,
        times: _selectedTimes.whereType<TimeOfDay>().toList(),
        notes: _notes,
        addedBy: currentUser.uid,
        createdAt: widget.medicationToEdit!.createdAt,
        updatedAt: Timestamp.now(),
        endDate: endDate, // ← NEW
      );

      try {
        final doc = await docRef.get();
        final List<dynamic> currentMedsList = doc.data()?['medsList'] ?? [];

        final List<Map<String, dynamic>> updatedMedsList = currentMedsList.map((
          med,
        ) {
          if (med['id'] == updatedMed.id) {
            return updatedMed.toMap();
          }
          return med as Map<String, dynamic>;
        }).toList();

        await docRef.update({'medsList': updatedMedsList});
        MedicationScheduler().scheduleAllMedications(widget.elderlyId);

        if (mounted) {
          Navigator.of(context).pop(true); // Close add/edit screen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Medication Updated Successfully',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.55,
                left: 20,
                right: 20,
              ),
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating medication: $e')),
          );
        }
      }
    } else {
      // --- ADD NEW LOGIC ---
      final newMed = Medication(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _medicationName ?? 'Unnamed',
        doseForm: _doseForm,
        doseStrength: _doseStrength,
        days: _selectedDays,
        frequency: _frequency,
        times: _selectedTimes.whereType<TimeOfDay>().toList(),
        notes: _notes,
        addedBy: currentUser.uid,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        endDate: endDate, // ← NEW
      );

      try {
        await docRef.set({
          'medsList': FieldValue.arrayUnion([newMed.toMap()]),
        }, SetOptions(merge: true));
        MedicationScheduler().scheduleAllMedications(widget.elderlyId);

        if (mounted) {
          Navigator.of(context).pop(); // Close add screen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Medication Added Successfully',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.55,
                left: 20,
                right: 20,
              ),
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving medication: $e')),
          );
        }
      }
    }
  }

  String _formatEndDate(int days) {
    final end = DateTime.now().add(Duration(days: days));
    return DateFormat('MMM d, yyyy').format(end);
  }

  // ═══════════════════════════════════════════
  // Elderly-Friendly Scan Preview Sheet
  // ═══════════════════════════════════════════
  Future<bool?> _showEditableScanSheet({required MedicationScanResult result}) {
    final nameCtrl = TextEditingController(text: result.name ?? '');
    final notesCtrl = TextEditingController(text: result.notes ?? '');
    final strengthCtrl = TextEditingController(
      text: result.patientDose ?? result.doseStrength ?? '',
    );

    String? selectedFreq = result.frequency;
    String? selectedForm = result.doseForm;

    final List<String> scanMissing = result.missingFields;
    final bool isLabel = result.isLikelyMedLabel;

    int? selectedDuration = result.durationDays;
    DateTime? scanCustomEndDate;

    // Wheel picker state for OCR duration
    int ocrDurUnit = 0; // 0=Days, 1=Weeks, 2=Months
    int ocrDurCount = 7;
    String ocrDurMode = 'wheel'; // 'wheel' | 'ongoing' | 'custom'
    const ocrUnits = ['Days', 'Weeks', 'Months'];
    const ocrMaxVals = [30, 12, 12];

    // Initialize from scanned duration
    if (selectedDuration == null || selectedDuration == 0) {
      ocrDurMode = 'ongoing';
    } else if (selectedDuration == -1) {
      ocrDurMode = 'custom';
    } else if (selectedDuration! > 0) {
      ocrDurMode = 'wheel';
      if (selectedDuration! % 30 == 0 && selectedDuration! ~/ 30 <= 12) {
        ocrDurUnit = 2;
        ocrDurCount = selectedDuration! ~/ 30;
      } else if (selectedDuration! % 7 == 0 && selectedDuration! ~/ 7 <= 12) {
        ocrDurUnit = 1;
        ocrDurCount = selectedDuration! ~/ 7;
      } else {
        ocrDurUnit = 0;
        ocrDurCount = selectedDuration!.clamp(1, 30);
      }
    }
    final ocrWheelCtrl = FixedExtentScrollController(
      initialItem: ocrDurCount - 1,
    );

    List<String> selectedDays = result.days.isNotEmpty
        ? List<String>.from(result.days)
        : <String>[];

    const allDays = [
      'Every day',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    List<String> getAllowedDays() {
      int? totalDays;
      if (selectedDuration != null && selectedDuration! > 0) {
        totalDays = selectedDuration;
      } else if (selectedDuration == -1 && scanCustomEndDate != null) {
        totalDays = scanCustomEndDate!.difference(DateTime.now()).inDays + 1;
      }
      if (totalDays == null || totalDays >= 7) return allDays.sublist(1);
      final now = DateTime.now();
      final daySet = <String>{};
      for (int i = 0; i < totalDays; i++) {
        final date = now.add(Duration(days: i));
        daySet.add(DateFormat('EEEE').format(date));
      }
      return allDays.sublist(1).where((d) => daySet.contains(d)).toList();
    }

    void constrainDays() {
      final allowed = getAllowedDays();
      selectedDays.removeWhere((d) => d != 'Every day' && !allowed.contains(d));
      if (selectedDays.contains('Every day') && allowed.length < 7) {
        selectedDays = List.from(allowed);
      }
    }

    const freqOptions = [
      'Once a day',
      'Twice a day',
      'Three times a day',
      'Four times a day',
    ];

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.80,
          minChildSize: 0.50,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: StatefulBuilder(
                    builder: (context, setSheetState) {
                      void toggleDay(String d) {
                        setSheetState(() {
                          final allowed = getAllowedDays();
                          if (d == 'Every day') {
                            if (!selectedDays.contains('Every day')) {
                              selectedDays = ['Every day', ...allowed];
                            } else {
                              selectedDays.clear();
                            }
                            return;
                          }
                          if (selectedDays.contains(d)) {
                            selectedDays.remove(d);
                          } else {
                            selectedDays.add(d);
                          }
                          if (allowed.every((x) => selectedDays.contains(x)) &&
                              allowed.length == 7) {
                            selectedDays = ['Every day', ...allowed];
                          } else {
                            selectedDays.remove('Every day');
                          }
                        });
                      }

                      final hasName = nameCtrl.text.trim().isNotEmpty;
                      final hasFreq = selectedFreq != null;
                      final hasDays = selectedDays.isNotEmpty;
                      final canApply = hasName && hasFreq && hasDays;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 50,
                              height: 6,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          // Title row
                          Row(
                            children: [
                              const Icon(
                                Icons.qr_code_scanner,
                                color: Color(0xFF5FA5A0),
                                size: 32,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Scan Preview',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ═══ NOT A LABEL WARNING ═══
                          if (!isLabel)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.red.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade700,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'This doesn\'t look like a medication label. '
                                      'Please take a clear photo of the prescription sticker or medication box.',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.red.shade800,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ═══ MISSING FIELDS ALERT ═══
                          if (isLabel && scanMissing.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange.shade800,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Could not detect:',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ...scanMissing.map(
                                          (f) => Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              '• $f',
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Please fill them in manually below, or take a clearer photo.',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.orange.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ═══ ALL DETECTED SUCCESS ═══
                          if (isLabel && scanMissing.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'All fields detected successfully! Please verify before applying.',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ═══ Medication Name ═══
                          const Text(
                            'Medication Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameCtrl,
                            onChanged: (_) => setSheetState(() {}),
                            style: const TextStyle(fontSize: 22),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.egPanadol,
                              hintStyle: const TextStyle(fontSize: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ═══ Duration ═══
                          // ═══ Duration ═══
                          const Text(
                            'Duration',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Unit selector: Days / Weeks / Months
                          Row(
                            children: List.generate(3, (i) {
                              final sel =
                                  ocrDurMode == 'wheel' && ocrDurUnit == i;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: i == 0 ? 0 : 4,
                                    right: i == 2 ? 0 : 4,
                                  ),
                                  child: ChoiceChip(
                                    label: SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        ocrUnits[i],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: sel
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: sel
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    selected: sel,
                                    onSelected: (_) => setSheetState(() {
                                      ocrDurMode = 'wheel';
                                      ocrDurUnit = i;
                                      if (ocrDurCount > ocrMaxVals[i]) {
                                        ocrDurCount = ocrMaxVals[i];
                                      }
                                      ocrWheelCtrl.jumpToItem(ocrDurCount - 1);
                                      // Sync selectedDuration
                                      final mult = [1, 7, 30][ocrDurUnit];
                                      selectedDuration = ocrDurCount * mult;
                                      scanCustomEndDate = null;
                                      constrainDays();
                                    }),
                                    selectedColor: const Color(0xFF0D2D5D),
                                    backgroundColor: Colors.grey.shade100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    showCheckmark: false,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 6),

                          // Compact wheel picker
                          if (ocrDurMode == 'wheel')
                            Container(
                              height: 130,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F8FC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFF0D2D5D,
                                  ).withOpacity(0.12),
                                ),
                              ),
                              child: CupertinoPicker(
                                scrollController: ocrWheelCtrl,
                                itemExtent: 42,
                                diameterRatio: 1.2,
                                selectionOverlay: Container(
                                  decoration: BoxDecoration(
                                    border: Border.symmetric(
                                      horizontal: BorderSide(
                                        color: const Color(
                                          0xFF0D2D5D,
                                        ).withOpacity(0.18),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                onSelectedItemChanged: (index) {
                                  setSheetState(() {
                                    ocrDurCount = index + 1;
                                    final mult = [1, 7, 30][ocrDurUnit];
                                    selectedDuration = ocrDurCount * mult;
                                    constrainDays();
                                  });
                                },
                                children: List.generate(
                                  ocrMaxVals[ocrDurUnit],
                                  (i) => Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0D2D5D),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // End date preview
                          if (ocrDurMode == 'wheel')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${ocrDurCount} ${ocrUnits[ocrDurUnit].toLowerCase()}  •  Ends ${_formatEndDate(selectedDuration!)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF104541),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Ongoing + Custom row
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.all_inclusive, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'Ongoing',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                  selected: ocrDurMode == 'ongoing',
                                  onSelected: (_) => setSheetState(() {
                                    ocrDurMode = 'ongoing';
                                    selectedDuration = null;
                                    scanCustomEndDate = null;
                                    constrainDays();
                                  }),
                                  selectedColor: const Color(
                                    0xFF0860A4,
                                  ).withOpacity(0.3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          ocrDurMode == 'custom' &&
                                                  scanCustomEndDate != null
                                              ? DateFormat(
                                                  'MMM d',
                                                ).format(scanCustomEndDate!)
                                              : 'Custom',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                  selected: ocrDurMode == 'custom',
                                  onSelected: (_) async {
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          scanCustomEndDate ??
                                          now.add(const Duration(days: 7)),
                                      firstDate: now,
                                      lastDate: now.add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        ocrDurMode = 'custom';
                                        selectedDuration = -1;
                                        scanCustomEndDate = picked;
                                        constrainDays();
                                      });
                                    }
                                  },
                                  selectedColor: const Color(
                                    0xFF0860A4,
                                  ).withOpacity(0.3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (ocrDurMode == 'custom' &&
                              scanCustomEndDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Ends ${DateFormat('MMM d, yyyy').format(scanCustomEndDate!)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF104541),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),

                          // ═══ Frequency ═══
                          const Text(
                            'Frequency',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: freqOptions.map((opt) {
                              final selected = selectedFreq == opt;
                              return ChoiceChip(
                                label: Text(
                                  opt,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                selected: selected,
                                onSelected: (_) =>
                                    setSheetState(() => selectedFreq = opt),
                                selectedColor: const Color(
                                  0xFF0860A4,
                                ).withOpacity(0.3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // ═══ Days ═══
                          const Text(
                            'Days',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (_) {
                              final allowed = getAllowedDays();
                              final isLimited = allowed.length < 7;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isLimited)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Only showing days within your duration',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: const Color(0xFF104541),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      if (!isLimited)
                                        FilterChip(
                                          label: const Text(
                                            'Every day',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                          selected: selectedDays.contains(
                                            'Every day',
                                          ),
                                          onSelected: (_) =>
                                              toggleDay('Every day'),
                                          selectedColor: const Color(
                                            0xFF0860A4,
                                          ).withOpacity(0.3),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        ),
                                      ...allowed.map((d) {
                                        return FilterChip(
                                          label: Text(
                                            d,
                                            style: const TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                          selected: selectedDays.contains(d),
                                          onSelected: (_) => toggleDay(d),
                                          selectedColor: const Color(
                                            0xFF0860A4,
                                          ).withOpacity(0.3),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // ═══ Notes ═══
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 20),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.optionalInstructions,
                              hintStyle: const TextStyle(fontSize: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ═══ Buttons ═══
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context, null),
                                  icon: const Icon(Icons.refresh, size: 28),
                                  label: const Text(
                                    'Rescan',
                                    style: TextStyle(fontSize: 22),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canApply
                                        ? const Color(0xFF285272)
                                        : Colors.grey.shade400,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: canApply
                                      ? () {
                                          setState(() {
                                            _medicationName = nameCtrl.text
                                                .trim();
                                            _doseForm = selectedForm;
                                            _doseStrength =
                                                strengthCtrl.text
                                                    .trim()
                                                    .isNotEmpty
                                                ? strengthCtrl.text.trim()
                                                : null;
                                            _notes = notesCtrl.text.trim();
                                            _notes = notesCtrl.text.trim();
                                            _selectedDays = List<String>.from(
                                              selectedDays,
                                            );
                                            _frequency = selectedFreq;

                                            if (selectedDuration != null &&
                                                selectedDuration! > 0) {
                                              _durationDays = selectedDuration;
                                              _customEndDate = DateTime.now()
                                                  .add(
                                                    Duration(
                                                      days: selectedDuration!,
                                                    ),
                                                  );
                                            } else if (selectedDuration == -1 &&
                                                scanCustomEndDate != null) {
                                              _durationDays = -1;
                                              _customEndDate =
                                                  scanCustomEndDate;
                                            } else {
                                              _durationDays = null;
                                              _customEndDate = null;
                                            }

                                            if (_frequency != null) {
                                              _initializeTimesForFrequency(
                                                _frequency!,
                                              );
                                            }
                                          });
                                          Navigator.pop(context, true);
                                        }
                                      : null,
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 28,
                                  ),
                                  label: Text(
                                    canApply ? 'Apply' : 'Fill all fields',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Camera Scan
  // ═══════════════════════════════════════════
  Future<void> _scanFromCamera() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      final XFile? shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (shot == null) return;

      final result = await _scanService.scanImage(File(shot.path));
      if (!mounted) return;

      final action = await _showEditableScanSheet(result: result);

      // null = Rescan
      if (action == null) {
        setState(() => _isScanning = false);
        await _scanFromCamera();
        return;
      }

      // false = Cancel
      if (action != true) return;

      if (!mounted) return;

      // After apply: go to dose step so user can verify/fill dose info
      // Steps: 0=Name, 1=Duration, 2=Days, 3=Frequency, 4=Dose, 5=Times, 6=Notes, 7=Summary
      int targetPage;
      if (_medicationName == null || _medicationName!.isEmpty) {
        targetPage = 0; // name is missing
      } else if (_durationDays == null && _customEndDate == null) {
        targetPage = 1; // duration not set
      } else if (_selectedDays.isEmpty) {
        targetPage = 2; // days not set
      } else if (_frequency == null) {
        targetPage = 3; // frequency not set
      } else {
        targetPage = 4; // dose step — verify/fill from scan
      }
      _pageController.jumpToPage(targetPage);
      setState(() => _currentPageIndex = targetPage);
    } catch (e) {
      debugPrint('\u{274C} Scan failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // --- UI Navigation and State Management (mostly unchanged) ---
  void _goToNextPage() {
    if (_currentPageIndex < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _initializeTimesForFrequency(String selectedFrequency) {
    setState(() {
      _frequency = selectedFrequency;
      if (selectedFrequency == 'Once a day') {
        _selectedTimes = [null];
      } else if (selectedFrequency == 'Twice a day') {
        _selectedTimes = [null, null];
      } else if (selectedFrequency == 'Three times a day') {
        _selectedTimes = [null, null, null];
      } else if (selectedFrequency == 'Four times a day') {
        _selectedTimes = [null, null, null, null];
      } else {
        _selectedTimes = [null];
      }
    });
  }

  void _updateTimes(int index, TimeOfDay newTime) {
    setState(() {
      _selectedTimes[index] = newTime;
      if (index == 0) {
        if (_frequency == 'Twice a day' && _selectedTimes.length == 2) {
          _selectedTimes[1] = TimeOfDay(
            hour: (newTime.hour + 12) % 24,
            minute: newTime.minute,
          );
        } else if (_frequency == 'Three times a day' &&
            _selectedTimes.length == 3) {
          _selectedTimes[1] = TimeOfDay(
            hour: (newTime.hour + 8) % 24,
            minute: newTime.minute,
          );
          _selectedTimes[2] = TimeOfDay(
            hour: (newTime.hour + 16) % 24,
            minute: newTime.minute,
          );
        } else if (_frequency == 'Four times a day' &&
            _selectedTimes.length == 4) {
          _selectedTimes[1] = TimeOfDay(
            hour: (newTime.hour + 6) % 24,
            minute: newTime.minute,
          );
          _selectedTimes[2] = TimeOfDay(
            hour: (newTime.hour + 12) % 24,
            minute: newTime.minute,
          );
          _selectedTimes[3] = TimeOfDay(
            hour: (newTime.hour + 18) % 24,
            minute: newTime.minute,
          );
        }
      }
    });
  }

  void _clearAllTimes() {
    setState(() {
      for (int i = 0; i < _selectedTimes.length; i++) {
        _selectedTimes[i] = null;
      }
    });
  }

  void _addCustomTimeField() {
    setState(() {
      _selectedTimes.add(null);
    });
  }

  void _removeCustomTimeField(int index) {
    if (_selectedTimes.length > 1 && index >= 0) {
      // Safety check
      setState(() {
        _selectedTimes.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle tealButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF5FA5A0),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(70),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      elevation: 6,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 110,
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
        titleTextStyle: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        backgroundColor: const Color(0xFF1B3A52),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: _goToPreviousPage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: Column(
        children: [
          _Stepper(currentIndex: _currentPageIndex, stepCount: 8),
          if (!_isEditing && _currentPageIndex == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanFromCamera,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 30),
                  label: Text(
                    _isScanning ? 'Scanning...' : 'Scan Prescription',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3A52),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          if (!_isEditing && _currentPageIndex == 0) const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1MedName(
                  initialValue: _medicationName,
                  buttonStyle: tealButtonStyle,
                  onNext: (name) {
                    setState(() => _medicationName = name);
                    _goToNextPage();
                  },
                ),
                _Step2Duration(
                  medicationName: _medicationName,
                  initialDurationDays: _durationDays,
                  initialCustomEndDate: _customEndDate,
                  buttonStyle: tealButtonStyle,
                  onNext: (days, customDate) {
                    setState(() {
                      _durationDays = days;
                      _customEndDate = customDate;
                    });
                    _goToNextPage();
                  },
                ),
                _Step3SelectDays(
                  key: ValueKey(
                    'days_${_durationDays}_${_customEndDate?.millisecondsSinceEpoch}',
                  ),
                  medicationName: _medicationName,
                  durationDays: _durationDays,
                  customEndDate: _customEndDate,
                  initialDays: _selectedDays,
                  buttonStyle: tealButtonStyle,
                  onNext: (days) {
                    setState(() => _selectedDays = days);
                    _goToNextPage();
                  },
                ),

                //
                _Step4HowManyTimesPerDay(
                  medicationName: _medicationName,
                  initialFrequency: _frequency,
                  buttonStyle: tealButtonStyle,
                  onNext: (freq) {
                    if (_frequency != freq) {
                      _initializeTimesForFrequency(freq);
                    }
                    setState(() => _frequency = freq);
                    _goToNextPage();
                  },
                ),
                _Step2Dose(
                  medicationName: _medicationName,
                  initialForm: _doseForm,
                  initialStrength: _doseStrength,
                  buttonStyle: tealButtonStyle,
                  onNext: (form, strength) {
                    setState(() {
                      _doseForm = form;
                      _doseStrength = strength;
                    });
                    _goToNextPage();
                  },
                ),
                _Step5SetTimes(
                  medicationName: _medicationName,
                  frequency: _frequency,
                  selectedTimes: _selectedTimes,
                  buttonStyle: tealButtonStyle,
                  onTimeChanged: _updateTimes,
                  onClearTimes: _clearAllTimes,
                  onAddTime: _frequency == 'Custom'
                      ? _addCustomTimeField
                      : null,
                  onRemoveTime: _frequency == 'Custom'
                      ? _removeCustomTimeField
                      : null,
                  onNext: () {
                    _goToNextPage();
                  },
                ),

                _Step6AddNotes(
                  medicationName: _medicationName,
                  initialNotes: _notes,
                  buttonStyle: tealButtonStyle,
                  onNext: (notes) {
                    setState(() => _notes = notes);
                    _goToNextPage();
                  },
                ),
                _Step8Summary(
                  key: ValueKey(
                    'summary_${_durationDays}_${_customEndDate?.millisecondsSinceEpoch}',
                  ),
                  medicationName: _medicationName,
                  doseForm: _doseForm,
                  doseStrength: _doseStrength,
                  durationDays: _durationDays,
                  customEndDate: _customEndDate,
                  selectedDays: _selectedDays,
                  frequency: _frequency,
                  selectedTimes: _selectedTimes.whereType<TimeOfDay>().toList(),
                  notes: _notes,
                  isEditing: _isEditing,
                  buttonStyle: tealButtonStyle,
                  onSave: _saveMedication,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Stepper and Header Widgets ---
class _Stepper extends StatelessWidget {
  final int currentIndex;
  final int stepCount;
  const _Stepper({required this.currentIndex, this.stepCount = 7});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
      child: Row(
        children: List.generate(stepCount, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              height: 10.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: index <= currentIndex
                    ? const Color(0xFF5FA5A0)
                    : Colors.grey.shade300,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? medicationName;

  const _StepHeader({
    required this.title,
    required this.subtitle,
    this.medicationName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medicationName != null && medicationName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              medicationName!,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B3A52),
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 20, color: Colors.grey, height: 1.3),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

Widget _elderlyCard({required Widget child}) {
  return Card(
    elevation: 6,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20.0),
      side: BorderSide(
        color: const Color(0xFF5FA5A0).withOpacity(0.2),
        width: 2,
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(24.0), child: child),
  );
}

// --- Step 1: Medicine Name ---
class _Step1MedName extends StatefulWidget {
  final ValueChanged<String> onNext;
  final String? initialValue;
  final ButtonStyle buttonStyle;
  const _Step1MedName({
    required this.onNext,
    this.initialValue,
    required this.buttonStyle,
  });

  @override
  State<_Step1MedName> createState() => _Step1MedNameState();
}

class _Step1MedNameState extends State<_Step1MedName> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _elderlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              title: 'Step 1: Medicine Name',
              subtitle: 'What medication do you need to take?',
            ),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.medicineName,
                labelStyle: const TextStyle(fontSize: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _nameController.text.trim().isNotEmpty
                  ? () => widget.onNext(_nameController.text.trim())
                  : null,
              style: widget.buttonStyle,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Step 5: Dose (NEW — Elderly-Friendly)
// ═══════════════════════════════════════════
class _Step2Dose extends StatefulWidget {
  final String? medicationName;
  final String? initialForm;
  final String? initialStrength;
  final ButtonStyle buttonStyle;
  final void Function(String? form, String? strength) onNext;
  const _Step2Dose({
    this.medicationName,
    this.initialForm,
    this.initialStrength,
    required this.buttonStyle,
    required this.onNext,
  });
  @override
  State<_Step2Dose> createState() => _Step2DoseState();
}

class _Step2DoseState extends State<_Step2Dose> {
  String? _selectedForm;
  late final TextEditingController _strengthCtrl;

  static const List<Map<String, dynamic>> _formOptions = [
    //{'label': 'Tablet', 'icon': Icons.medication},
    {'label': 'Capsule', 'icon': Icons.medication},
    {'label': 'Syrup', 'icon': Icons.local_drink},
    {'label': 'Cream/Ointment', 'icon': Icons.back_hand_outlined},
    {'label': 'Eye Drops', 'icon': Icons.visibility},
    {'label': 'Ear Drops', 'icon': Icons.hearing},
    {'label': 'Nasal Spray', 'icon': Icons.air},
    //{'label': 'Inhaler', 'icon': Icons.masks},
    {'label': 'Injection', 'icon': Icons.vaccines},
    //{'label': 'Patch', 'icon': Icons.healing},
    //{'label': 'Suppository', 'icon': Icons.medical_services},
    //{'label': 'Powder/Sachet', 'icon': Icons.inventory_2},
    {'label': 'Other', 'icon': Icons.more_horiz},
  ];

  /// Suggest a contextual strength hint based on the selected form.
  String get _strengthHint {
    switch (_selectedForm) {
      case 'Capsule':
        return 'e.g. 500 mg, 1 tablet';
      case 'Syrup':
        return 'e.g. 5 ml, 10 ml';
      case 'Cream/Ointment':
        return 'e.g. apply thin layer, 0.5%';
      case 'Eye Drops':
      case 'Ear Drops':
        return 'e.g. 2 drops';
      case 'Nasal Spray':
        return 'e.g. 1 spray each nostril';
      case 'Injection':
        return 'e.g. 0.5 ml, 10 units';
      default:
        return 'e.g. 500 mg, 5 ml, 2 puffs';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedForm = widget.initialForm;
    _strengthCtrl = TextEditingController(text: widget.initialStrength);
  }

  @override
  void dispose() {
    _strengthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = _selectedForm != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _elderlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              medicationName: widget.medicationName,
              title: 'Step 5: Dose',
              subtitle: 'What form and strength is this medication?',
            ),

            const Text(
              'Medication Form',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _formOptions.map((opt) {
                final label = opt['label'] as String;
                final icon = opt['icon'] as IconData;
                final isSelected = _selectedForm == label;
                return ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? const Color(0xFF1B3A52)
                        : Colors.grey.shade600,
                  ),
                  label: Text(label, style: const TextStyle(fontSize: 20)),

                  selected: isSelected,
                  showCheckmark: false,
                  elevation: 0,
                  pressElevation: 0,
                  onSelected: (_) =>
                      setState(() => _selectedForm = isSelected ? null : label),
                  selectedColor: const Color(0xFF0860A4).withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            const Text(
              'Strength / Dose',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _strengthCtrl,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                hintText: _strengthHint,
                hintStyle: const TextStyle(fontSize: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: canProceed
                  ? () {
                      widget.onNext(
                        _selectedForm,
                        _strengthCtrl.text.trim().isNotEmpty
                            ? _strengthCtrl.text.trim()
                            : null,
                      );
                    }
                  : null,
              style: widget.buttonStyle,
              child: const Text('Next'),
            ),
            if (!canProceed)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Please select a medication form to continue',
                    style: TextStyle(fontSize: 20, color: Colors.grey.shade500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// --- Step 2: Select Days (Each day has its own colored box) ---

class _Step2Duration extends StatefulWidget {
  final String? medicationName;
  final int? initialDurationDays;
  final DateTime? initialCustomEndDate;
  final ButtonStyle buttonStyle;
  final void Function(int? durationDays, DateTime? customEndDate) onNext;
  const _Step2Duration({
    this.medicationName,
    this.initialDurationDays,
    this.initialCustomEndDate,
    required this.buttonStyle,
    required this.onNext,
  });
  @override
  State<_Step2Duration> createState() => _Step2DurationState();
}

class _Step2DurationState extends State<_Step2Duration> {
  // 'wheel' | 'ongoing' | 'custom'
  String _mode = 'wheel';
  int _unitIndex = 0; // 0=Days, 1=Weeks, 2=Months
  late FixedExtentScrollController _wheelCtrl;
  int _count = 7; // default: 7 days
  DateTime? _customDate;

  static const _units = ['Days', 'Weeks', 'Months'];
  static const _maxValues = [30, 12, 12];

  @override
  void initState() {
    super.initState();
    final init = widget.initialDurationDays;
    _customDate = widget.initialCustomEndDate;

    if (init == null || init == 0) {
      // Ongoing
      _mode = 'ongoing';
      _count = 7;
    } else if (init == -1) {
      // Custom
      _mode = 'custom';
      _count = 7;
    } else {
      _mode = 'wheel';
      // Reverse-engineer best unit
      if (init % 30 == 0 && init ~/ 30 <= 12) {
        _unitIndex = 2;
        _count = init ~/ 30;
      } else if (init % 7 == 0 && init ~/ 7 <= 12) {
        _unitIndex = 1;
        _count = init ~/ 7;
      } else {
        _unitIndex = 0;
        _count = init.clamp(1, 30);
      }
    }
    _wheelCtrl = FixedExtentScrollController(initialItem: _count - 1);
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    super.dispose();
  }

  int get _totalDays {
    switch (_unitIndex) {
      case 1:
        return _count * 7;
      case 2:
        return _count * 30;
      default:
        return _count;
    }
  }

  String _endDateLabel(int days) {
    final end = DateTime.now().add(Duration(days: days));
    return 'Ends ${DateFormat('MMM d, yyyy').format(end)}';
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF367470)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _mode = 'custom';
        _customDate = picked;
      });
    }
  }

  void _switchUnit(int newIndex) {
    setState(() {
      _unitIndex = newIndex;
      // Clamp count to new max
      if (_count > _maxValues[newIndex]) {
        _count = _maxValues[newIndex];
      }
      _wheelCtrl.dispose();
      _wheelCtrl = FixedExtentScrollController(initialItem: _count - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed =
        _mode == 'ongoing' ||
        _mode == 'wheel' ||
        (_mode == 'custom' && _customDate != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _elderlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              medicationName: widget.medicationName,
              title: 'Step 2: Duration',
              subtitle: 'How long should this medication be taken?',
            ),

            // ── Unit selector chips ──
            Row(
              children: List.generate(3, (i) {
                final selected = _mode == 'wheel' && _unitIndex == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 5,
                      right: i == 2 ? 0 : 5,
                    ),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          _units[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: selected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _mode = 'wheel');
                        _switchUnit(i);
                      },
                      selectedColor: const Color(0xFF0D2D5D),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // ── Wheel picker ──
            if (_mode == 'wheel')
              Container(
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0D2D5D).withOpacity(0.15),
                  ),
                ),
                child: CupertinoPicker(
                  scrollController: _wheelCtrl,
                  itemExtent: 48,
                  diameterRatio: 1.2,
                  selectionOverlay: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: const Color(0xFF0D2D5D).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() => _count = index + 1);
                  },
                  children: List.generate(
                    _maxValues[_unitIndex],
                    (i) => Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D2D5D),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── End date preview ──
            if (_mode == 'wheel')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    '${_count} ${_units[_unitIndex].toLowerCase()}  •  ${_endDateLabel(_totalDays)}',
                    style: TextStyle(
                      fontSize: 18,
                      color: const Color(0xFF367470),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),
            // ── Divider ──
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Custom Date option ──
            GestureDetector(
              onTap: _pickCustomDate,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _mode == 'custom'
                      ? const Color.fromARGB(255, 239, 246, 253)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _mode == 'custom'
                        ? const Color(0xFF0D2D5D)
                        : const Color(0xFF5FA5A0).withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'custom',
                      groupValue: _mode,
                      onChanged: (_) => _pickCustomDate(),
                      activeColor: const Color.fromARGB(255, 34, 79, 133),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 24,
                      color: Color(0xFF5FA5A0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mode == 'custom' && _customDate != null
                            ? 'Custom: ${DateFormat('MMM d, yyyy').format(_customDate!)}'
                            : 'Pick a specific end date',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: _mode == 'custom'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_mode == 'custom' && _customDate != null)
                      TextButton(
                        onPressed: _pickCustomDate,
                        child: const Text(
                          'Change',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Ongoing option ──
            GestureDetector(
              onTap: () => setState(() {
                _mode = 'ongoing';
                _customDate = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _mode == 'ongoing'
                      ? const Color.fromARGB(255, 239, 246, 253)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _mode == 'ongoing'
                        ? const Color(0xFF0D2D5D)
                        : const Color(0xFF5FA5A0).withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    if (_mode == 'ongoing')
                      BoxShadow(
                        color: const Color(0xFF5FA5A0).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'ongoing',
                      groupValue: _mode,
                      onChanged: (v) => setState(() {
                        _mode = 'ongoing';
                        _customDate = null;
                      }),
                      activeColor: const Color.fromARGB(255, 34, 79, 133),
                    ),
                    const Icon(
                      Icons.all_inclusive,
                      size: 24,
                      color: Color(0xFF5FA5A0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ongoing (No end date)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: _mode == 'ongoing'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _mode == 'ongoing'
                              ? const Color.fromARGB(255, 26, 48, 95)
                              : const Color.fromARGB(255, 52, 52, 52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: canProceed
                  ? () {
                      if (_mode == 'ongoing') {
                        widget.onNext(null, null);
                        return;
                      }
                      if (_mode == 'custom') {
                        widget.onNext(-1, _customDate);
                        return;
                      }
                      // wheel mode
                      final days = _totalDays;
                      final endDate = DateTime.now().add(Duration(days: days));
                      widget.onNext(days, endDate);
                    }
                  : null,
              style: widget.buttonStyle,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////

class _Step3SelectDays extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<List<String>> onNext;
  final List<String>? initialDays;
  final int? durationDays;
  final DateTime? customEndDate;
  final ButtonStyle buttonStyle;
  const _Step3SelectDays({
    super.key,
    this.medicationName,
    required this.onNext,
    this.initialDays,
    this.durationDays,
    this.customEndDate,
    required this.buttonStyle,
  });
  @override
  State<_Step3SelectDays> createState() => _Step3SelectDaysState();
}

class _Step3SelectDaysState extends State<_Step3SelectDays> {
  static const _allDays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  List<String> _selectedDays = [];

  /// Compute which day-names fall within the duration.
  List<String> get _allowedDays {
    int? totalDays;
    if (widget.durationDays != null && widget.durationDays! > 0) {
      totalDays = widget.durationDays;
    } else if (widget.durationDays == -1 && widget.customEndDate != null) {
      totalDays = widget.customEndDate!.difference(DateTime.now()).inDays + 1;
    }
    if (totalDays == null || totalDays >= 7) return _allDays;

    final now = DateTime.now();
    final daySet = <String>{};
    for (int i = 0; i < totalDays; i++) {
      final date = now.add(Duration(days: i));
      daySet.add(DateFormat('EEEE').format(date));
    }
    return _allDays.where((d) => daySet.contains(d)).toList();
  }

  bool get _isDurationLimited {
    if (widget.durationDays == null) return false;
    if (widget.durationDays! > 0 && widget.durationDays! < 7) return true;
    if (widget.durationDays == -1 && widget.customEndDate != null) {
      return widget.customEndDate!.difference(DateTime.now()).inDays + 1 < 7;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDays != null)
      _selectedDays = List.from(widget.initialDays!);
    _selectedDays.removeWhere(
      (d) => d != 'Every day' && !_allowedDays.contains(d),
    );
    if (_selectedDays.contains('Every day') && _isDurationLimited) {
      _selectedDays = ['Every day', ..._allowedDays];
    }
  }

  void _onDaySelected(bool? value, String day) {
    final allowed = _allowedDays;
    setState(() {
      if (day == 'Every day') {
        if (value == true) {
          _selectedDays = ['Every day', ...allowed];
        } else {
          _selectedDays.clear();
        }
      } else {
        if (value == true) {
          _selectedDays.add(day);
          _selectedDays.remove('Every day');
        } else {
          _selectedDays.remove(day);
        }
        if (allowed.every((d) => _selectedDays.contains(d))) {
          _selectedDays = ['Every day', ...allowed];
        }
      }
    });
  }

  Widget _buildDayTile(String day, {String? suffix}) {
    final isSelected = _selectedDays.contains(day);
    return GestureDetector(
      onTap: () => _onDaySelected(!isSelected, day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 239, 246, 253)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D2D5D)
                : const Color(0xFF5FA5A0).withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  214,
                  225,
                  224,
                ).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => _onDaySelected(v, day),
              activeColor: const Color.fromARGB(255, 34, 79, 133),
            ),
            Expanded(
              child: Text(
                suffix != null ? '$day $suffix' : day,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? const Color.fromARGB(255, 26, 48, 95)
                      : const Color.fromARGB(255, 52, 52, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowedDays;
    final limited = _isDurationLimited;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              medicationName: widget.medicationName,
              title: 'Step 3: Select Days',
              subtitle: 'Which days should you take this medication?',
            ),
            if (limited)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 244, 249, 248),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF5FA5A0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF0D2D5D),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.durationDays != null && widget.durationDays! > 0
                            ? 'Based on your ${widget.durationDays}-day duration, only these days apply.'
                            : 'Based on your selected end date, only these days apply.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D2D5D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Daily Schedule',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 21, 31, 79),
              ),
            ),
            const SizedBox(height: 8),
            _buildDayTile(
              'Every day',
              suffix: limited ? '(${allowed.length} days)' : null,
            ),
            const SizedBox(height: 16),
            Text(
              limited ? 'Available Days' : 'Specific Days',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 17, 23, 50),
              ),
            ),
            const SizedBox(height: 8),
            ...allowed.map((day) => _buildDayTile(day)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _selectedDays.isNotEmpty
                  ? () => widget.onNext(_selectedDays)
                  : null,
              style: widget.buttonStyle,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Step 3: Frequency---
class _Step4HowManyTimesPerDay extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<String> onNext;
  final String? initialFrequency;
  final ButtonStyle buttonStyle;

  const _Step4HowManyTimesPerDay({
    this.medicationName,
    required this.onNext,
    this.initialFrequency,
    required this.buttonStyle,
  });

  @override
  State<_Step4HowManyTimesPerDay> createState() =>
      _Step4HowManyTimesPerDayState();
}

class _Step4HowManyTimesPerDayState extends State<_Step4HowManyTimesPerDay> {
  String? _selectedFrequency;
  final List<String> _frequencyOptions = [
    'Once a day',
    'Twice a day',
    'Three times a day',
    'Four times a day',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFrequency = widget.initialFrequency;
  }

  Widget _buildFrequencyTile(String option) {
    final bool isSelected = _selectedFrequency == option;

    return GestureDetector(
      onTap: () => setState(() => _selectedFrequency = option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 239, 246, 253)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D2D5D)
                : const Color(0xFF5FA5A0).withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Radio<String>(
              value: option,
              groupValue: _selectedFrequency,
              onChanged: (value) => setState(() => _selectedFrequency = value),
              activeColor: const Color.fromARGB(255, 34, 79, 133),
            ),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? const Color.fromARGB(255, 26, 48, 95)
                      : const Color.fromARGB(255, 52, 52, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 6,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: const Color(0xFF5FA5A0).withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                medicationName: widget.medicationName,
                title: 'Step 4: Frequency',
                subtitle: 'Select how often you take this medication',
              ),
              const SizedBox(height: 16),
              ..._frequencyOptions.map(_buildFrequencyTile),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _selectedFrequency != null
                    ? () => widget.onNext(_selectedFrequency!)
                    : null,
                style: widget.buttonStyle,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Step 4: Set Times ---
class _Step5SetTimes extends StatefulWidget {
  final String? medicationName;
  final String? frequency;
  final List<TimeOfDay?> selectedTimes;
  final Function(int, TimeOfDay) onTimeChanged;
  final VoidCallback onNext;
  final VoidCallback onClearTimes;
  final VoidCallback? onAddTime;
  final ValueChanged<int>? onRemoveTime;
  final ButtonStyle buttonStyle;

  const _Step5SetTimes({
    this.medicationName,
    required this.frequency,
    required this.selectedTimes,
    required this.onTimeChanged,
    required this.onNext,
    required this.onClearTimes,
    this.onAddTime,
    this.onRemoveTime,
    required this.buttonStyle,
  });

  @override
  State<_Step5SetTimes> createState() => _Step5SetTimesState();
}

class _Step5SetTimesState extends State<_Step5SetTimes> {
  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.selectedTimes[index] ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5FA5A0)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      widget.onTimeChanged(index, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCustom = widget.frequency == 'Custom';
    bool allTimesSelected = widget.selectedTimes.every((time) => time != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 6,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: const Color(0xFF5FA5A0).withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                medicationName: widget.medicationName,
                title: 'Step 5: Set Times',
                subtitle: 'When should you take this medication?',
              ),
              ...widget.selectedTimes.asMap().entries.map((entry) {
                int index = entry.key;
                TimeOfDay? time = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(index),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              )!.timeNumber(index + 1),
                              labelStyle: const TextStyle(fontSize: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                            ),
                            child: Text(
                              time?.format(context) ?? 'Select a time',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                      if (isCustom && widget.onRemoveTime != null)
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                              size: 32,
                            ),
                            onPressed: () => widget.onRemoveTime!(index),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              if (isCustom && widget.onAddTime != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onAddTime,
                    icon: const Icon(Icons.add_circle_outline, size: 28),
                    label: const Text(
                      'Add another time',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onClearTimes,
                  child: const Text(
                    'Clear All Times',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: allTimesSelected
                    ? widget.onNext
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select all required times.',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        );
                      },
                style: widget.buttonStyle,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Step 5: Add Notes---
class _Step6AddNotes extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<String?> onNext;
  final String? initialNotes;
  final ButtonStyle buttonStyle;

  const _Step6AddNotes({
    this.medicationName,
    required this.onNext,
    this.initialNotes,
    required this.buttonStyle,
  });

  @override
  State<_Step6AddNotes> createState() => _Step6AddNotesState();
}

class _Step6AddNotesState extends State<_Step6AddNotes> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 6,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: const Color(0xFF5FA5A0).withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                medicationName: widget.medicationName,
                title: 'Step 6: Add Notes',
                subtitle: 'Any special instructions? (Optional)',
              ),
              TextField(
                controller: _notesController,
                maxLines: 5,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.notes,
                  labelStyle: const TextStyle(fontSize: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => widget.onNext(_notesController.text),
                style: widget.buttonStyle,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step8Summary extends StatelessWidget {
  final String? medicationName, doseForm, doseStrength, frequency, notes;
  final int? durationDays;
  final DateTime? customEndDate;
  final List<String> selectedDays;
  final List<TimeOfDay> selectedTimes;
  final VoidCallback onSave;
  final bool isEditing;
  final ButtonStyle buttonStyle;

  const _Step8Summary({
    super.key,
    this.medicationName,
    this.doseForm,
    this.doseStrength,
    this.durationDays,
    this.customEndDate,
    required this.selectedDays,
    this.frequency,
    required this.selectedTimes,
    this.notes,
    required this.onSave,
    required this.isEditing,
    required this.buttonStyle,
  });

  String _durationLabel() {
    if (durationDays != null && durationDays! > 0) {
      final end =
          customEndDate ?? DateTime.now().add(Duration(days: durationDays!));
      return '$durationDays days (until ${DateFormat('MMM d, yyyy').format(end)})';
    }
    if (durationDays == -1 && customEndDate != null)
      return 'Until ${DateFormat('MMM d, yyyy').format(customEndDate!)}';
    if (customEndDate != null)
      return 'Until ${DateFormat('MMM d, yyyy').format(customEndDate!)}';
    return 'Ongoing (no end date)';
  }

  String _doseLabel() {
    final parts = <String>[];
    if (doseForm != null) parts.add(doseForm!);
    if (doseStrength != null && doseStrength!.isNotEmpty)
      parts.add(doseStrength!);
    return parts.isEmpty ? 'Not specified' : parts.join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    final formattedTimes = selectedTimes
        .map((t) => t.format(context))
        .join(', ');
    final formattedDays = selectedDays.join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: _StepHeader(
              title: 'Step 8: Summary',
              subtitle: 'Please review the information before saving.',
            ),
          ),
          _elderlyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryTile(
                  title: 'Medication Name',
                  value: medicationName ?? 'N/A',
                ),
                _SummaryTile(title: 'Dose', value: _doseLabel()),
                _SummaryTile(title: 'Duration', value: _durationLabel()),
                _SummaryTile(title: 'Frequency', value: frequency ?? 'N/A'),
                _SummaryTile(title: 'Days', value: formattedDays),
                _SummaryTile(title: 'Times', value: formattedTimes),
                if (notes != null && notes!.isNotEmpty)
                  _SummaryTile(title: 'Notes', value: notes!),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: onSave,
              style: buttonStyle,
              child: Text(isEditing ? 'Save Changes' : 'Add Medication'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title, value;
  const _SummaryTile({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
