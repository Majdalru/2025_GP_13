import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/medication.dart';
import '../../services/medication_scheduler.dart';
import 'package:intl/intl.dart';

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
  int? _durationDays; // ← NEW
  DateTime? _customEndDate; // ← NEW
  List<String> _selectedDays = [];
  String? _frequency;
  List<TimeOfDay?> _selectedTimes = [];
  String? _notes;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.medicationToEdit != null;

    if (_isEditing) {
      final med = widget.medicationToEdit!;
      _medicationName = med.name;
      _selectedDays = List.from(med.days);
      _frequency = med.frequency;
      // Ensure selectedTimes is mutable
      _selectedTimes = List<TimeOfDay?>.from(med.times);
      _notes = med.notes;

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
    if (_customEndDate != null) {
      return Timestamp.fromDate(
        DateTime(
          _customEndDate!.year,
          _customEndDate!.month,
          _customEndDate!.day,
          23,
          59,
          59,
        ),
      );
    }
    if (_durationDays != null && _durationDays! > 0) {
      final startDate = _isEditing
          ? widget.medicationToEdit!.createdAt.toDate()
          : DateTime.now();
      final end = startDate.add(Duration(days: _durationDays!));
      return Timestamp.fromDate(
        DateTime(end.year, end.month, end.day, 23, 59, 59),
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

  // --- UI Navigation and State Management (mostly unchanged) ---
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
              const _StepHeader(
                title: 'Step 1: Medicine Name',
                subtitle: 'What medication do you need to take?',
              ),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  labelText: 'Medicine Name',
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
      ),
    );
  }
} // --- Step 2: Select Days (Each day has its own colored box) ---

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
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF5FA5A0)),
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
        (_selected! > 0 || (_selected == -1 && _customDate != null));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
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
                          color: const Color(0xFF5FA5A0).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                    ],
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
                        activeColor: const Color.fromARGB(255, 34, 79, 133),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color.fromARGB(255, 26, 48, 95)
                                    : const Color.fromARGB(255, 52, 52, 52),
                              ),
                            ),
                            if (sub.isNotEmpty)
                              Text(
                                sub,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Text(
                          _endDateLabel(days),
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color.fromARGB(255, 16, 101, 95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            // Custom date option
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
                  color: _selected == -1
                      ? const Color.fromARGB(255, 239, 246, 253)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _selected == -1
                        ? const Color(0xFF0D2D5D)
                        : const Color(0xFF5FA5A0).withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<int>(
                      value: -1,
                      groupValue: _selected,
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
                        _selected == -1 && _customDate != null
                            ? 'Custom: ${DateFormat('MMM d, yyyy').format(_customDate!)}'
                            : 'Custom Date',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: _selected == -1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_selected == -1 && _customDate != null)
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

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: canProceed
                  ? () {
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
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => widget.onNext(null, null),
                child: const Text(
                  'Skip (Ongoing medication)',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ),
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
                              labelText: 'Time ${index + 1}',
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
                  labelText: 'Notes',
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

// --- Step 6: Summary  ---
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
    // Preset chosen (3, 5, 7, 10, 14, 30)
    if (durationDays != null && durationDays! > 0) {
      final end =
          customEndDate ?? DateTime.now().add(Duration(days: durationDays!));
      return '$durationDays days (until ${DateFormat('MMM d, yyyy').format(end)})';
    }
    // Custom date chosen
    if (durationDays == -1 && customEndDate != null) {
      return 'Until ${DateFormat('MMM d, yyyy').format(customEndDate!)}';
    }
    // Fallback: customEndDate set but durationDays is null
    if (customEndDate != null) {
      return 'Until ${DateFormat('MMM d, yyyy').format(customEndDate!)}';
    }
    // Skipped / ongoing
    return 'Ongoing (no end date)';
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
              title: 'Step 7: Summary',
              subtitle: 'Please review the information before saving.',
            ),
          ),
          Card(
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
