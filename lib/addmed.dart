import 'package:flutter/material.dart';
import 'medmain.dart'; // Or wherever your Medication class is

// --- Main Stateful Widget for AddMedScreen ---
class AddMedScreen extends StatefulWidget {
  // Add an optional parameter to accept the medication being edited
  final Medication? medicationToEdit;

  const AddMedScreen({super.key, this.medicationToEdit});

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

class _AddMedScreenState extends State<AddMedScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  late final bool _isEditing;

  // --- Data collected from the form ---
  String? _medicationName;
  List<String> _selectedDays = [];
  String? _frequency;
  List<TimeOfDay?> _selectedTimes = [];
  String? _notes;

  @override
  void initState() {
    super.initState();
    // Check if we are in "edit mode"
    _isEditing = widget.medicationToEdit != null;

    // If we are editing, pre-fill all the state variables
    if (_isEditing) {
      final med = widget.medicationToEdit!;
      _medicationName = med.name;
      _selectedDays = List.from(
        med.days,
      ); // Use List.from to create a mutable copy
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        // Dynamically change the title
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: const Color.fromRGBO(12, 45, 93, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToPreviousPage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10), // Adjust the radius as needed
          ),
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
                  // Pass initial value for editing
                  initialValue: _medicationName,
                  onNext: (name) {
                    setState(() => _medicationName = name);
                    _goToNextPage();
                  },
                ),
                _Step2SelectDays(
                  medicationName: _medicationName,
                  // Pass initial value for editing
                  initialDays: _selectedDays,
                  onNext: (days) {
                    setState(() => _selectedDays = days);
                    _goToNextPage();
                  },
                ),
                _Step3HowManyTimesPerDay(
                  medicationName: _medicationName,
                  // Pass initial value for editing
                  initialFrequency: _frequency,
                  onNext: (freq) {
                    // Only re-initialize times if the frequency changes
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
                  // Pass initial value for editing
                  initialNotes: _notes,
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
                  // Pass editing status to change button text
                  isEditing: _isEditing,
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

// --- Stepper and Header Widgets (Unchanged) ---
class _Stepper extends StatelessWidget {
  final int currentIndex;
  final int stepCount;
  const _Stepper({required this.currentIndex, this.stepCount = 5});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(stepCount, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            width: 55.0,
            height: 12.0,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
              color: index == currentIndex ? Colors.teal : Colors.grey.shade300,
            ),
          );
        }),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String? medicationName;

  const _StepHeader({
    required this.stepNumber,
    required this.title,
    this.medicationName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medicationName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              medicationName!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        Text(
          stepNumber,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 24),
      ],
    );
  }
}

// --- Updated Step Widgets to accept initial values ---

class _Step1MedName extends StatefulWidget {
  final ValueChanged<String> onNext;
  final String? initialValue;
  const _Step1MedName({required this.onNext, this.initialValue});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            stepNumber: 'Step 1: Enter Medicine Name',
            title: 'What medication do you need to take?',
            medicationName: widget.initialValue,
          ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Medicine Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                widget.onNext(_nameController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _Step2SelectDays extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<List<String>> onNext;
  final List<String>? initialDays;
  const _Step2SelectDays({
    this.medicationName,
    required this.onNext,
    this.initialDays,
  });

  @override
  State<_Step2SelectDays> createState() => _Step2SelectDaysState();
}

class _Step2SelectDaysState extends State<_Step2SelectDays> {
  final List<String> _daysOfWeek = [
    'Everyday',
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            medicationName: widget.medicationName,
            stepNumber: 'Step 2: Select Days',
            title: 'Which days should you take this medication?',
          ),
          ..._daysOfWeek.map(
            (day) => CheckboxListTile(
              title: Text(day),
              value: _selectedDays.contains(day),
              onChanged: (bool? value) => setState(() {
                if (value == true)
                  _selectedDays.add(day);
                else
                  _selectedDays.remove(day);
              }),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_selectedDays.isNotEmpty) {
                widget.onNext(_selectedDays);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _Step3HowManyTimesPerDay extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<String> onNext;
  final String? initialFrequency;
  const _Step3HowManyTimesPerDay({
    this.medicationName,
    required this.onNext,
    this.initialFrequency,
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            medicationName: widget.medicationName,
            stepNumber: 'Step 3: How Many Times Per Day?',
            title: 'Select how often you take this medication',
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
            onPressed: () {
              if (_selectedFrequency != null) {
                widget.onNext(_selectedFrequency!);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _Step4SetTimes extends StatefulWidget {
  final String? medicationName;
  final String? frequency;
  final List<TimeOfDay?> selectedTimes;
  final Function(int, TimeOfDay) onTimeChanged;
  final VoidCallback onNext;
  final VoidCallback onClearTimes;
  final VoidCallback? onAddTime;
  final ValueChanged<int>? onRemoveTime;

  const _Step4SetTimes({
    this.medicationName,
    required this.frequency,
    required this.selectedTimes,
    required this.onTimeChanged,
    required this.onNext,
    required this.onClearTimes,
    this.onAddTime,
    this.onRemoveTime,
  });

  @override
  State<_Step4SetTimes> createState() => _Step4SetTimesState();
}

class _Step4SetTimesState extends State<_Step4SetTimes> {
  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.selectedTimes[index] ?? TimeOfDay.now(),
    );
    if (picked != null) {
      widget.onTimeChanged(index, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCustom = widget.frequency == 'Custom';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            medicationName: widget.medicationName,
            stepNumber: 'Step 4: Set Times',
            title: 'When should you take this medication?',
          ),
          ...widget.selectedTimes.asMap().entries.map((entry) {
            int index = entry.key;
            TimeOfDay? time = entry.value;
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
            onPressed: () {
              if (widget.selectedTimes.every((time) => time != null)) {
                widget.onNext();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select all required times.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _Step5AddNotes extends StatefulWidget {
  final String? medicationName;
  final ValueChanged<String?> onNext;
  final String? initialNotes;
  const _Step5AddNotes({
    this.medicationName,
    required this.onNext,
    this.initialNotes,
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            medicationName: widget.medicationName,
            stepNumber: 'Step 5: Add Notes (Optional)',
            title: 'Any special instructions?',
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
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _Step6Summary extends StatelessWidget {
  final String? medicationName;
  final List<String> selectedDays;
  final String? frequency;
  final List<TimeOfDay> selectedTimes;
  final String? notes;
  final VoidCallback onSave;
  final bool isEditing;

  const _Step6Summary({
    this.medicationName,
    required this.selectedDays,
    this.frequency,
    required this.selectedTimes,
    this.notes,
    required this.onSave,
    required this.isEditing,
  });

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
          _StepHeader(
            medicationName: medicationName,
            stepNumber: 'Step 6: Summary & Confirm',
            title: 'Please review the information before saving.',
          ),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            // Dynamically change button text
            child: Text(isEditing ? 'Save Changes' : 'Add Medication'),
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
