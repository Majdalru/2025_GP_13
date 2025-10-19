import 'package:flutter/material.dart';
import 'elderly_med.dart';

// --- Main Stateful Widget for AddMedScreen ---
class AddMedScreen extends StatefulWidget {
  final Medication? medicationToEdit;

  const AddMedScreen({super.key, this.medicationToEdit});

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

class _AddMedScreenState extends State<AddMedScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late final bool _isEditing;

  String? _medicationName;
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
      _selectedTimes = List.from(med.times);
      _notes = med.notes;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPageIndex < 5) {
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
      if (selectedFrequency == 'Once daily') {
        _selectedTimes = [null];
      } else if (selectedFrequency == 'Twice daily') {
        _selectedTimes = [null, null];
      } else if (selectedFrequency == 'Three times daily') {
        _selectedTimes = [null, null, null];
      } else if (selectedFrequency == 'Four times daily') {
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
        if (_frequency == 'Twice daily' && _selectedTimes.length == 2) {
          _selectedTimes[1] = TimeOfDay(
            hour: (newTime.hour + 12) % 24,
            minute: newTime.minute,
          );
        } else if (_frequency == 'Three times daily' &&
            _selectedTimes.length == 3) {
          _selectedTimes[1] = TimeOfDay(
            hour: (newTime.hour + 8) % 24,
            minute: newTime.minute,
          );
          _selectedTimes[2] = TimeOfDay(
            hour: (newTime.hour + 16) % 24,
            minute: newTime.minute,
          );
        } else if (_frequency == 'Four times daily' &&
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

  void _saveMedication() {
    final updatedMedication = Medication(
      name: _medicationName ?? 'Unnamed Medication',
      days: _selectedDays,
      frequency: _frequency,
      times: _selectedTimes.whereType<TimeOfDay>().toList(),
      notes: _notes,
    );
    Navigator.pop(context, updatedMedication);
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle tealButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF5FA5A0),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(70),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: Column(
        children: [
          _Stepper(currentIndex: _currentPageIndex, stepCount: 6),
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
                _Step2SelectDays(
                  medicationName: _medicationName,
                  initialDays: _selectedDays,
                  buttonStyle: tealButtonStyle,
                  onNext: (days) {
                    setState(() => _selectedDays = days);
                    _goToNextPage();
                  },
                ),
                _Step3HowManyTimesPerDay(
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
                _Step4SetTimes(
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
                    setState(() {
                      _selectedTimes = _selectedTimes
                          .where((t) => t != null)
                          .toList();
                    });
                    _goToNextPage();
                  },
                ),
                _Step5AddNotes(
                  medicationName: _medicationName,
                  initialNotes: _notes,
                  buttonStyle: tealButtonStyle,
                  onNext: (notes) {
                    setState(() => _notes = notes);
                    _goToNextPage();
                  },
                ),
                _Step6Summary(
                  medicationName: _medicationName,
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
  const _Stepper({required this.currentIndex, this.stepCount = 5});

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
          style: const TextStyle(
            fontSize: 20,
            color: Colors.grey,
            height: 1.3,
          ),
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
}

// --- Step 2: Select Days ---
class _Step2SelectDays extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<List<String>> onNext;
  final List<String>? initialDays;
  final ButtonStyle buttonStyle;

  const _Step2SelectDays({
    this.medicationName,
    required this.onNext,
    this.initialDays,
    required this.buttonStyle,
  });

  @override
  State<_Step2SelectDays> createState() => _Step2SelectDaysState();
}

class _Step2SelectDaysState extends State<_Step2SelectDays> {
  final List<String> _daysOfWeek = [
    'Every day',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  List<String> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialDays != null) {
      _selectedDays = List.from(widget.initialDays!);
    }
  }

  void _onDaySelected(bool? value, String day) {
    setState(() {
      if (day == 'Every day') {
        if (value == true) {
          _selectedDays = List.from(_daysOfWeek);
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
        if (_daysOfWeek.sublist(1).every((d) => _selectedDays.contains(d))) {
          _selectedDays = List.from(_daysOfWeek);
        }
      }
    });
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
                title: 'Step 2: Select Days',
                subtitle: 'Which days should you take this medication?',
              ),
              ..._daysOfWeek.map(
                (day) => CheckboxListTile(
                  title: Text(
                    day,
                    style: const TextStyle(fontSize: 22),
                  ),
                  value: _selectedDays.contains(day),
                  onChanged: (bool? value) => _onDaySelected(value, day),
                  activeColor: const Color(0xFF5FA5A0),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
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
      ),
    );
  }
}

// --- Step 3: Frequency ---
class _Step3HowManyTimesPerDay extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<String> onNext;
  final String? initialFrequency;
  final ButtonStyle buttonStyle;

  const _Step3HowManyTimesPerDay({
    this.medicationName,
    required this.onNext,
    this.initialFrequency,
    required this.buttonStyle,
  });

  @override
  State<_Step3HowManyTimesPerDay> createState() =>
      _Step3HowManyTimesPerDayState();
}

class _Step3HowManyTimesPerDayState extends State<_Step3HowManyTimesPerDay> {
  String? _selectedFrequency;
  final List<String> _frequencyOptions = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
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
                title: 'Step 3: Frequency',
                subtitle: 'Select how often you take this medication',
              ),
              ..._frequencyOptions.map(
                (option) => RadioListTile<String>(
                  title: Text(
                    option,
                    style: const TextStyle(fontSize: 22),
                  ),
                  value: option,
                  groupValue: _selectedFrequency,
                  onChanged: (String? value) =>
                      setState(() => _selectedFrequency = value),
                  activeColor: const Color(0xFF5FA5A0),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
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
class _Step4SetTimes extends StatefulWidget {
  final String? medicationName;
  final String? frequency;
  final List<TimeOfDay?> selectedTimes;
  final Function(int, TimeOfDay) onTimeChanged;
  final VoidCallback onNext;
  final VoidCallback onClearTimes;
  final VoidCallback? onAddTime;
  final ValueChanged<int>? onRemoveTime;
  final ButtonStyle buttonStyle;

  const _Step4SetTimes({
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
  State<_Step4SetTimes> createState() => _Step4SetTimesState();
}

class _Step4SetTimesState extends State<_Step4SetTimes> {
  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.selectedTimes[index] ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5FA5A0),
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
                title: 'Step 4: Set Times',
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
                      if (isCustom && index > 0 && widget.onRemoveTime != null)
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

// --- Step 5: Add Notes ---
class _Step5AddNotes extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<String?> onNext;
  final String? initialNotes;
  final ButtonStyle buttonStyle;

  const _Step5AddNotes({
    this.medicationName,
    required this.onNext,
    this.initialNotes,
    required this.buttonStyle,
  });

  @override
  State<_Step5AddNotes> createState() => _Step5AddNotesState();
}

class _Step5AddNotesState extends State<_Step5AddNotes> {
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
                title: 'Step 5: Add Notes',
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

// --- Step 6: Summary ---
class _Step6Summary extends StatelessWidget {
  final String? medicationName;
  final List<String> selectedDays;
  final String? frequency;
  final List<TimeOfDay> selectedTimes;
  final String? notes;
  final VoidCallback onSave;
  final bool isEditing;
  final ButtonStyle buttonStyle;

  const _Step6Summary({
    this.medicationName,
    required this.selectedDays,
    this.frequency,
    required this.selectedTimes,
    this.notes,
    required this.onSave,
    required this.isEditing,
    required this.buttonStyle,
  });

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
              title: 'Step 6: Summary',
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
  final String title;
  final String value;
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