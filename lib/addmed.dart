import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'models/medication.dart';
import 'services/medication_scheduler.dart';
import 'services/medication_scan_service.dart';
import 'package:intl/intl.dart';

// ===============================
//  CAREGIVER Add/Edit Medication
// ===============================
class AddMedScreen extends StatefulWidget {
  final Medication? medicationToEdit;
  final String elderlyId;

  // ✅ new: if true, open camera automatically on screen open (only when adding)
  final bool autoScanOnOpen;

  // ✅ new: start from a specific step (0..5). default = 0.
  final int startFromStep;

  const AddMedScreen({
    super.key,
    this.medicationToEdit,
    required this.elderlyId,
    this.autoScanOnOpen = false,
    this.startFromStep = 0,
  });

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

class _AddMedScreenState extends State<AddMedScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late final bool _isEditing;

  String? _medicationName;
  int? _durationDays;
  DateTime? _customEndDate; // ← NEW: for custom date pick or preset calc
  List<String> _selectedDays = [];
  String? _frequency;
  List<TimeOfDay?> _selectedTimes = [];
  String? _notes;

  // Scan (camera + OCR)
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
      _selectedDays = List.from(med.days);
      _frequency = med.frequency;
      _selectedTimes = List<TimeOfDay?>.from(med.times);
      _notes = med.notes;

      // ← NEW: restore duration from endDate
      if (med.endDate != null) {
        _customEndDate = med.endDate!.toDate();
        final diff = _customEndDate!.difference(med.createdAt.toDate()).inDays;
        if ([3, 5, 7, 10, 14, 30].contains(diff)) {
          _durationDays = diff;
        } else {
          _durationDays = -1; // custom
        }
      }
    }

    // ✅ Start from a specific step if requested
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final start = widget.startFromStep.clamp(0, 6);
      if (start != 0) {
        _pageController.jumpToPage(start);
        setState(() => _currentPageIndex = start);
      }

      // ✅ Auto open camera if requested (only when adding, not editing)
      if (widget.autoScanOnOpen && !_isEditing) {
        await _scanFromCamera();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scanService.dispose();
    super.dispose();
  }

  // ← NEW: compute the Timestamp endDate for Firestore
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

  String _formatEndDate(int days) {
    final end = DateTime.now().add(Duration(days: days));
    return DateFormat('MMM d, yyyy').format(end);
  }

  Future<bool?> _showEditableScanSheet({required MedicationScanResult result}) {
    final nameCtrl = TextEditingController(text: result.name ?? '');
    final notesCtrl = TextEditingController(text: result.notes ?? '');

    String? selectedFreq = result.frequency;
    int? selectedDuration = result.durationDays; // ← NEW: from scan
    DateTime? scanCustomEndDate; // ← for custom date pick in scan sheet

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

    // Compute which day-names fall within the duration window
    List<String> getAllowedDays() {
      int? totalDays;
      if (selectedDuration != null && selectedDuration! > 0) {
        totalDays = selectedDuration;
      } else if (selectedDuration == -1 && scanCustomEndDate != null) {
        totalDays = scanCustomEndDate!.difference(DateTime.now()).inDays + 1;
      }
      // Ongoing or ≥7 → all days reachable
      if (totalDays == null || totalDays >= 7) return allDays.sublist(1);
      final now = DateTime.now();
      final daySet = <String>{};
      for (int i = 0; i < totalDays; i++) {
        final date = now.add(Duration(days: i));
        daySet.add(DateFormat('EEEE').format(date));
      }
      return allDays.sublist(1).where((d) => daySet.contains(d)).toList();
    }

    // Auto-select days within duration window
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
      'Custom',
    ];

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: StatefulBuilder(
                    builder: (context, setSheetState) {
                      void toggleDay(String d) {
                        setSheetState(() {
                          final allowed = getAllowedDays();

                          if (d == 'Every day') {
                            final isOn = selectedDays.contains('Every day');
                            if (!isOn) {
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

                          // if all allowed days selected -> mark as Every day
                          if (allowed.every((x) => selectedDays.contains(x)) &&
                              allowed.length == 7) {
                            selectedDays = ['Every day', ...allowed];
                          } else {
                            selectedDays.remove('Every day');
                          }
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          Row(
                            children: [
                              const Icon(
                                Icons.qr_code_scanner,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Scan Preview',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          const Text(
                            'Medication name',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              hintText: 'e.g. Fusidic Acid',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ═══════════ Duration (NEW) ═══════════
                          const Text(
                            'Duration',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...[3, 5, 7, 10, 14, 30].map((d) {
                                final selected = selectedDuration == d;
                                final label = d == 30
                                    ? '1 month'
                                    : d == 14
                                    ? '2 weeks'
                                    : '$d days';
                                return ChoiceChip(
                                  label: Text(label),
                                  selected: selected,
                                  onSelected: (_) => setSheetState(() {
                                    selectedDuration = selected ? null : d;
                                    scanCustomEndDate = null;
                                    constrainDays();
                                  }),
                                  selectedColor: Colors.teal.shade100,
                                );
                              }),
                              // Custom date chip
                              ChoiceChip(
                                label: Text(
                                  selectedDuration == -1 &&
                                          scanCustomEndDate != null
                                      ? 'Custom: ${DateFormat('MMM d').format(scanCustomEndDate!)}'
                                      : 'Custom',
                                ),
                                selected: selectedDuration == -1,
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
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: Theme.of(ctx).colorScheme
                                            .copyWith(primary: Colors.teal),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      selectedDuration = -1;
                                      scanCustomEndDate = picked;
                                      constrainDays();
                                    });
                                  }
                                },
                                selectedColor: Colors.teal.shade100,
                              ),
                              // Ongoing chip
                              ChoiceChip(
                                label: const Text('Ongoing'),
                                selected: selectedDuration == null,
                                onSelected: (_) => setSheetState(() {
                                  selectedDuration = null;
                                  scanCustomEndDate = null;
                                  constrainDays();
                                }),
                                selectedColor: Colors.grey.shade300,
                              ),
                            ],
                          ),
                          if (selectedDuration != null &&
                              selectedDuration != -1 &&
                              selectedDuration! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Ends ${_formatEndDate(selectedDuration!)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ),
                          if (selectedDuration == -1 &&
                              scanCustomEndDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Ends ${DateFormat('MMM d, yyyy').format(scanCustomEndDate!)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // ═══════════════════════════════════════
                          const Text(
                            'Frequency',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: freqOptions.map((opt) {
                              final selected = selectedFreq == opt;
                              return ChoiceChip(
                                label: Text(opt),
                                selected: selected,
                                onSelected: (_) =>
                                    setSheetState(() => selectedFreq = opt),
                                selectedColor: Colors.teal.shade100,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Days',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
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
                                        'Only showing days within your ${selectedDuration == -1 ? "custom" : "$selectedDuration-day"} duration',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.teal.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (!isLimited)
                                        FilterChip(
                                          label: const Text('Every day'),
                                          selected: selectedDays.contains(
                                            'Every day',
                                          ),
                                          onSelected: (_) =>
                                              toggleDay('Every day'),
                                          selectedColor: Colors.teal.shade100,
                                        ),
                                      ...allowed.map((d) {
                                        final selected = selectedDays.contains(
                                          d,
                                        );
                                        return FilterChip(
                                          label: Text(d),
                                          selected: selected,
                                          onSelected: (_) => toggleDay(d),
                                          selectedColor: Colors.teal.shade100,
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Notes',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Optional instructions…',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context, null),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Rescan'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Builder(
                                  builder: (_) {
                                    final hasName = nameCtrl.text
                                        .trim()
                                        .isNotEmpty;
                                    final hasFreq = selectedFreq != null;
                                    final hasDays = selectedDays.isNotEmpty;
                                    final canApply =
                                        hasName && hasFreq && hasDays;

                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canApply
                                            ? Colors.teal
                                            : Colors.grey.shade400,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: canApply
                                          ? () {
                                              final name = nameCtrl.text.trim();

                                              setState(() {
                                                _medicationName = name;
                                                _notes = notesCtrl.text.trim();

                                                _selectedDays =
                                                    List<String>.from(
                                                      selectedDays,
                                                    );

                                                _frequency = selectedFreq;

                                                if (selectedDuration != null &&
                                                    selectedDuration! > 0) {
                                                  _durationDays =
                                                      selectedDuration;
                                                  _customEndDate =
                                                      DateTime.now().add(
                                                        Duration(
                                                          days:
                                                              selectedDuration!,
                                                        ),
                                                      );
                                                } else if (selectedDuration ==
                                                        -1 &&
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
                                      icon: const Icon(Icons.check_circle),
                                      label: Text(
                                        canApply ? 'Apply' : 'Fill all fields',
                                      ),
                                    );
                                  },
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

  // --------------------------------
  // Scan (Camera -> OCR -> Autofill)
  // --------------------------------
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

      // ✅ after apply: skip to the first step that still needs user input
      // Steps: 0=Name, 1=Duration, 2=Days, 3=Frequency, 4=Times, 5=Notes, 6=Summary
      int targetPage;
      if (_durationDays == null && _customEndDate == null) {
        targetPage = 1; // go to duration step
      } else if (_selectedDays.isEmpty) {
        targetPage = 2; // go to days step
      } else if (_frequency == null) {
        targetPage = 3; // go to frequency step
      } else {
        targetPage = 4; // everything filled, go to times
      }
      _pageController.jumpToPage(targetPage);
      setState(() => _currentPageIndex = targetPage);
    } catch (e) {
      debugPrint('❌ Scan failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ---------------------
  // Firestore Save Logic
  // ---------------------
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
      // UPDATE
      final updatedMed = Medication(
        id: widget.medicationToEdit!.id,
        name: _medicationName ?? 'Unnamed',
        days: _selectedDays,
        frequency: _frequency,
        times: _selectedTimes.whereType<TimeOfDay>().toList(),
        notes: _notes,
        addedBy: currentUser.uid,
        createdAt: widget.medicationToEdit!.createdAt,
        updatedAt: Timestamp.now(),
        endDate: endDate,
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
          Navigator.of(context).pop(true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Medication updated successfully',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error updating medication: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating medication: $e')),
          );
        }
      }
    } else {
      // ADD NEW
      final newMed = Medication(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _medicationName ?? 'Unnamed',
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
          Navigator.of(context).pop(true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Medication added successfully',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error saving medication: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving medication: $e')),
          );
        }
      }
    }
  }

  // ---------------------
  // UI Navigation Helpers
  // ---------------------
  void _goToNextPage() {
    if (_currentPageIndex < 6) {
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

  // ---------------------
  // Times + Frequency Logic
  // ---------------------
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
    if (_selectedTimes.length > 1 && index > 0) {
      setState(() {
        _selectedTimes.removeAt(index);
      });
    }
  }

  // ---------------------
  // Build
  // ---------------------
  @override
  Widget build(BuildContext context) {
    final ButtonStyle tealButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: const Color.fromRGBO(12, 45, 93, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goToPreviousPage,
        ),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: _isScanning ? null : _scanFromCamera,
            tooltip: 'Scan medication',
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: Column(
        children: [
          _Stepper(currentIndex: _currentPageIndex, stepCount: 7),
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
                _Step7Summary(
                  key: ValueKey(
                    'summary_${_durationDays}_${_customEndDate?.millisecondsSinceEpoch}',
                  ),
                  medicationName: _medicationName,
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

// =====================
// Stepper + Header
// =====================
class _Stepper extends StatelessWidget {
  final int currentIndex;
  final int stepCount;
  const _Stepper({required this.currentIndex, this.stepCount = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        children: List.generate(stepCount, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              height: 8.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: index <= currentIndex
                    ? Colors.teal
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
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              medicationName!,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// =====================
// Step 1
// =====================
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepHeader(
                title: 'Step 1: Medicine Name',
                subtitle: 'What medication do you need to take?',
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),
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
      ),
    );
  }
}

// =====================
// Step 2

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
  int? _selected;
  DateTime? _customDate;

  static const _presets = [
    {'days': 3, 'label': '3 Days', 'sub': ''},
    {'days': 5, 'label': '5 Days', 'sub': ''},
    {'days': 7, 'label': '7 Days (1 Week)', 'sub': ''},
    {'days': 10, 'label': '10 Days', 'sub': ''},
    {'days': 14, 'label': '14 Days (2 Weeks)', 'sub': ''},
    {'days': 30, 'label': '30 Days (1 Month)', 'sub': ''},
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDurationDays;
    _customDate = widget.initialCustomEndDate;
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
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: Colors.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() {
        _selected = -1;
        _customDate = picked;
      });
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed =
        _selected != null &&
        (_selected == 0 ||
            _selected! > 0 ||
            (_selected == -1 && _customDate != null));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                medicationName: widget.medicationName,
                title: 'Step 2: Duration',
                subtitle: 'How long should this medication be taken?',
              ),
              ..._presets.map((p) {
                final days = p['days'] as int;
                final label = p['label'] as String;
                final sub = p['sub'] as String;
                final isSelected = _selected == days;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selected = days;
                    _customDate = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: days,
                          groupValue: _selected,
                          onChanged: (v) => setState(() {
                            _selected = v;
                            _customDate = null;
                          }),
                          activeColor: Colors.teal,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              if (sub.isNotEmpty)
                                Text(
                                  sub,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _endDateLabel(days),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: _pickCustomDate,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: -1,
                        groupValue: _selected,
                        onChanged: (_) => _pickCustomDate(),
                        activeColor: Colors.teal,
                      ),
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selected == -1 && _customDate != null
                              ? 'Custom: ${DateFormat('MMM d, yyyy').format(_customDate!)}'
                              : 'Custom Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selected == -1
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_selected == -1 && _customDate != null)
                        TextButton(
                          onPressed: _pickCustomDate,
                          child: const Text('Change'),
                        ),
                    ],
                  ),
                ),
              ),
              // ═══ Ongoing option ═══
              GestureDetector(
                onTap: () => setState(() {
                  _selected = 0;
                  _customDate = null;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: 0,
                        groupValue: _selected,
                        onChanged: (v) => setState(() {
                          _selected = 0;
                          _customDate = null;
                        }),
                        activeColor: Colors.teal,
                      ),
                      const Icon(
                        Icons.all_inclusive,
                        size: 20,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ongoing (No end date)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selected == 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: canProceed
                    ? () {
                        if (_selected == 0) {
                          widget.onNext(null, null);
                          return;
                        }
                        DateTime? endDate;
                        if (_selected == -1) {
                          endDate = _customDate;
                        } else if (_selected != null && _selected! > 0) {
                          endDate = DateTime.now().add(
                            Duration(days: _selected!),
                          );
                        }
                        widget.onNext(_selected, endDate);
                      }
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

// =====================

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

  /// Compute which day-names are reachable within the duration.
  List<String> get _allowedDays {
    int? totalDays;
    if (widget.durationDays != null && widget.durationDays! > 0) {
      totalDays = widget.durationDays;
    } else if (widget.durationDays == -1 && widget.customEndDate != null) {
      totalDays = widget.customEndDate!.difference(DateTime.now()).inDays + 1;
    }
    // Ongoing or ≥7 → all days reachable
    if (totalDays == null || totalDays >= 7) return _allDays;

    final now = DateTime.now();
    final daySet = <String>{};
    for (int i = 0; i < totalDays; i++) {
      final date = now.add(Duration(days: i));
      daySet.add(DateFormat('EEEE').format(date));
    }
    // Return in canonical week order
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
    // Remove any previously selected days that are no longer allowed
    _selectedDays.removeWhere(
      (d) => d != 'Every day' && !_allowedDays.contains(d),
    );
    if (_selectedDays.contains('Every day') && _isDurationLimited) {
      _selectedDays = List.from(_allowedDays);
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
        // If all allowed days selected, add "Every day"
        if (allowed.every((d) => _selectedDays.contains(d))) {
          _selectedDays = ['Every day', ...allowed];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowedDays;
    final limited = _isDurationLimited;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.teal.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.durationDays != null &&
                                  widget.durationDays! > 0
                              ? 'Based on your ${widget.durationDays}-day duration, only the following days apply.'
                              : 'Based on your selected end date, only the following days apply.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Daily Schedule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              CheckboxListTile(
                title: Text(
                  limited ? 'Every day (${allowed.length} days)' : 'Every day',
                ),
                value: _selectedDays.contains('Every day'),
                onChanged: (v) => _onDaySelected(v, 'Every day'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  limited ? 'Available Days' : 'Specific Days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              ...allowed.map(
                (day) => CheckboxListTile(
                  title: Text(day),
                  value: _selectedDays.contains(day),
                  onChanged: (v) => _onDaySelected(v, day),
                ),
              ),
              const SizedBox(height: 32),
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
      ),
    );
  }
}

// =====================
// Step 3
// =====================
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                medicationName: widget.medicationName,
                title: 'Step 4: Frequency',
                subtitle: 'Select how often you take this medication',
              ),
              ..._frequencyOptions.map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedFrequency,
                  onChanged: (String? value) =>
                      setState(() => _selectedFrequency = value),
                ),
              ),
              const SizedBox(height: 32),
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

// =====================
// Step 4
// =====================
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
  State<_Step5SetTimes> createState() => _Step4SetTimesState();
}

class _Step4SetTimesState extends State<_Step5SetTimes> {
  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.selectedTimes[index] ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.teal,
              onPrimary: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
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
    final bool isCustom = widget.frequency == 'Custom';
    final bool allTimesSelected = widget.selectedTimes.every(
      (time) => time != null,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                medicationName: widget.medicationName,
                title: 'Step 5: Set Times',
                subtitle: 'When should you take this medication?',
              ),
              ...widget.selectedTimes.asMap().entries.map((entry) {
                final int index = entry.key;
                final TimeOfDay? time = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(index),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Time ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              time?.format(context) ?? 'Select a time',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      if (isCustom && index > 0 && widget.onRemoveTime != null)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => widget.onRemoveTime!(index),
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
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add another time'),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onClearTimes,
                  child: const Text('Clear All Times'),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: allTimesSelected
                    ? widget.onNext
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select all required times.'),
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

// =====================
// Step 5
// =====================
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
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
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

// =====================
// Step 6
// =====================
class _Step7Summary extends StatelessWidget {
  final String? medicationName;
  final int? durationDays;
  final DateTime? customEndDate;
  final List<String> selectedDays;
  final String? frequency;
  final List<TimeOfDay> selectedTimes;
  final String? notes;
  final VoidCallback onSave;
  final bool isEditing;
  final ButtonStyle buttonStyle;

  const _Step7Summary({
    super.key,
    this.medicationName,
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
    // customEndDate is always set when user picks a duration (preset or custom)
    if (customEndDate != null) {
      if (durationDays != null && durationDays! > 0) {
        return '$durationDays days (until ${DateFormat('MMM d, yyyy').format(customEndDate!)})';
      }
      return 'Until ${DateFormat('MMM d, yyyy').format(customEndDate!)}';
    }
    return 'Ongoing (no end date)';
  }

  @override
  Widget build(BuildContext context) {
    final formattedTimes = selectedTimes
        .map((t) => t.format(context))
        .join(', ');
    final formattedDays = selectedDays.join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: _StepHeader(
              title: 'Step 7: Summary',
              subtitle: 'Please review the information before saving.',
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryTile(
                    title: 'Medication Name',
                    value: medicationName ?? 'N/A',
                  ),
                  _SummaryTile(
                    title: 'Duration',
                    value: _durationLabel(),
                  ), // ← NEW
                  _SummaryTile(title: 'Frequency', value: frequency ?? 'N/A'),
                  _SummaryTile(title: 'Days', value: formattedDays),
                  _SummaryTile(title: 'Times', value: formattedTimes),
                  if (notes != null && notes!.isNotEmpty)
                    _SummaryTile(title: 'Notes', value: notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
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
  final String title;
  final String value;
  const _SummaryTile({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
