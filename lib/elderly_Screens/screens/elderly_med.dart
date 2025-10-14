import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MedicationAppRoot());
}

class MedicationAppRoot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medication Plan',
      theme: ThemeData(
        primaryColor: Color(0xFF6B7FD7),
        scaffoldBackgroundColor: Color(0xFFF8F9FD),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MedicationApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Medication {
  String id;
  String name;
  List<String> times;
  List<String> days;
  String notes;
  Map<String, String> status;

  Medication({
    required this.id,
    required this.name,
    required this.times,
    required this.days,
    required this.notes,
    required this.status,
  });

  factory Medication.fromJson(Map<String, dynamic> j) {
    return Medication(
      id: j['id'],
      name: j['name'],
      times: List<String>.from(j['times'] ?? []),
      days: List<String>.from(j['days'] ?? []),
      notes: j['notes'] ?? '',
      status: Map<String, String>.from(j['status'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'times': times,
        'days': days,
        'notes': notes,
        'status': status,
      };
}

const List<String> DAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday"
];

class MedicationApp extends StatefulWidget {
  @override
  _MedicationAppState createState() => _MedicationAppState();
}

class _MedicationAppState extends State<MedicationApp> {
  String view = "list"; // list | today | add
  List<Medication> medications = [];
  bool showDeleteConfirm = false;
  String deleteId = "";
  String deleteName = "";
  String searchQuery = "";

  // form state
  String? editingId;
  int step = 1;
  String medicineName = "";
  List<String> selectedDays = [];
  String frequency = "once";
  List<TimeOfDay> times = [TimeOfDay(hour: 12, minute: 0)];
  String notes = "";

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('medications');
    if (stored != null) {
      try {
        final list = jsonDecode(stored) as List;
        setState(() {
          medications = list.map((e) => Medication.fromJson(e)).toList();
        });
      } catch (e) {
        // ignore parse errors
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enc = jsonEncode(medications.map((m) => m.toJson()).toList());
    await prefs.setString('medications', enc);
  }

  void resetForm() {
    setState(() {
      step = 1;
      medicineName = "";
      selectedDays = [];
      frequency = "once";
      times = [TimeOfDay(hour: 12, minute: 0)];
      notes = "";
      editingId = null;
    });
  }

  String _timeToString(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  TimeOfDay _stringToTime(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';
      
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return TimeOfDay(hour: 12, minute: 0);
    }
  }

  void _distributeTimesEvenly(int count) {
    if (count == 1) {
      times = [TimeOfDay(hour: 12, minute: 0)];
    } else if (count == 2) {
      times = [
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 21, minute: 0),
      ];
    } else if (count == 3) {
      times = [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    } else {
      // For custom, distribute evenly throughout the day
      times = List.generate(count, (i) {
        final interval = 14 / (count - 1); // From 8 AM to 10 PM
        final hour = (8 + (i * interval)).round();
        return TimeOfDay(hour: hour, minute: 0);
      });
    }
  }

  void _recalculateTimes(int changedIndex) {
    if (times.length <= 1) return;
    
    final changedTime = times[changedIndex];
    final changedMinutes = changedTime.hour * 60 + changedTime.minute;
    
    if (changedIndex == 0) {
      // Changed first time - adjust all others proportionally
      final totalMinutes = 14 * 60; // 14 hours span
      final interval = totalMinutes / (times.length - 1);
      
      for (int i = 1; i < times.length; i++) {
        final newMinutes = changedMinutes + (interval * i).round();
        final hour = (newMinutes ~/ 60) % 24;
        final minute = newMinutes % 60;
        times[i] = TimeOfDay(hour: hour, minute: minute);
      }
    } else if (changedIndex == times.length - 1) {
      // Changed last time - adjust all others proportionally
      final totalMinutes = changedMinutes - (times[0].hour * 60 + times[0].minute);
      final interval = totalMinutes / (times.length - 1);
      
      for (int i = 1; i < times.length - 1; i++) {
        final firstMinutes = times[0].hour * 60 + times[0].minute;
        final newMinutes = firstMinutes + (interval * i).round();
        final hour = (newMinutes ~/ 60) % 24;
        final minute = newMinutes % 60;
        times[i] = TimeOfDay(hour: hour, minute: minute);
      }
    } else {
      // Changed middle time - adjust times after it
      final prevMinutes = times[changedIndex - 1].hour * 60 + times[changedIndex - 1].minute;
      final timeBetween = changedMinutes - prevMinutes;
      
      for (int i = changedIndex + 1; i < times.length; i++) {
        final prevTimeMinutes = times[i - 1].hour * 60 + times[i - 1].minute;
        final newMinutes = prevTimeMinutes + timeBetween;
        final hour = (newMinutes ~/ 60) % 24;
        final minute = newMinutes % 60;
        times[i] = TimeOfDay(hour: hour, minute: minute);
      }
    }
  }

  void handleEditClick(String id) {
    final medication = medications.firstWhere((m) => m.id == id, orElse: () => Medication(id: '', name: '', times: [], days: [], notes: '', status: {}));
    if (medication.id == '') return;
    setState(() {
      editingId = id;
      medicineName = medication.name;
      selectedDays = List.from(medication.days);
      times = medication.times.map((t) => _stringToTime(t)).toList();
      if (times.isEmpty) times = [TimeOfDay(hour: 12, minute: 0)];
      notes = medication.notes;
      if (medication.times.length == 1) frequency = "once";
      else if (medication.times.length == 2) frequency = "twice";
      else if (medication.times.length == 3) frequency = "three";
      else frequency = "custom";
      view = "add";
      step = 1;
    });
  }

  void handleDeleteClick(String id, String name) {
    setState(() {
      deleteId = id;
      deleteName = name;
      showDeleteConfirm = true;
    });
  }

  void confirmDelete() async {
    setState(() {
      medications.removeWhere((m) => m.id == deleteId);
      showDeleteConfirm = false;
      deleteId = "";
      deleteName = "";
    });
    await _saveToPrefs();
  }

  void cancelDelete() {
    setState(() {
      showDeleteConfirm = false;
      deleteId = "";
      deleteName = "";
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  String _getTodayName() {
    final now = DateTime.now();
    return DAYS[now.weekday % 7];
  }

  List<Medication> _getTodayMedications() {
    final today = _getTodayName();
    return medications.where((med) => med.days.contains(today)).toList();
  }

  void handleStatusChange(String id, String status) async {
    final today = _todayKey();
    setState(() {
      medications = medications.map((med) {
        if (med.id == id) {
          final newStatus = Map<String, String>.from(med.status);
          newStatus[today] = status;
          return Medication(
            id: med.id,
            name: med.name,
            times: med.times,
            days: med.days,
            notes: med.notes,
            status: newStatus,
          );
        }
        return med;
      }).toList();
    });
    await _saveToPrefs();
  }

  String getMedicationStatus(Medication med) {
    final today = _todayKey();
    return med.status[today] ?? "pending";
  }

  int getTimesCount() {
    if (frequency == "once") return 1;
    if (frequency == "twice") return 2;
    if (frequency == "three") return 3;
    return times.length;
  }

  void handleNext() {
    if (step == 1 && medicineName.trim().isEmpty) return;
    if (step == 2 && selectedDays.isEmpty) return;
    if (step == 3) {
      final count = getTimesCount();
      setState(() {
        _distributeTimesEvenly(count);
      });
    }
    setState(() {
      if (step < 5) step += 1;
    });
  }

  void handleDayToggle(String day) {
    setState(() {
      if (selectedDays.contains(day)) selectedDays.remove(day);
      else selectedDays.add(day);
    });
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: times[index],
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.3),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        times[index] = picked;
        if (times.length > 1) {
          _recalculateTimes(index);
        }
      });
    }
  }

  void handleAdd() async {
    final medication = Medication(
      id: editingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: medicineName,
      times: times.map((t) => _timeToString(t)).toList(),
      days: selectedDays,
      notes: notes,
      status: {},
    );

    setState(() {
      final storedIndex = medications.indexWhere((m) => m.id == medication.id);
      if (storedIndex != -1) {
        medications[storedIndex] = medication;
      } else {
        medications.add(medication);
      }
    });

    await _saveToPrefs();
    resetForm();
    setState(() {
      view = "today";
    });
  }

  List<bool> progressDots() {
    return List.generate(5, (i) => i < step);
  }

  Color statusBgColor(String status) {
    if (status == "taken") return Color(0xFFE8F5E9);
    if (status == "missed") return Color(0xFFFFEBEE);
    return Color(0xFFFFF3E0);
  }

  Color statusTextColor(String status) {
    if (status == "taken") return Color(0xFF2E7D32);
    if (status == "missed") return Color(0xFFC62828);
    return Color(0xFFE65100);
  }

  Widget buildTodayView() {
    final todayMeds = _getTodayMedications();
    final todayName = _getTodayName();

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        leading: Padding(
          padding: EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF6B7FD7), size: 32),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Medications',
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            Text(
              todayName,
              style: TextStyle(
                color: Color(0xFF8F92A1),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  view = "list";
                });
              },
              icon: Icon(Icons.list_rounded, size: 28, color: Color(0xFF6B7FD7)),
              label: Text(
                'All Meds',
                style: TextStyle(fontSize: 18, color: Color(0xFF6B7FD7), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: todayMeds.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F6FA),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.celebration_rounded,
                        size: 80,
                        color: Color(0xFF66BB6A),
                      ),
                    ),
                    SizedBox(height: 28),
                    Text(
                      'No Medications Today',
                      style: TextStyle(
                        fontSize: 28,
                        color: Color(0xFF2D3142),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Enjoy your day!',
                      style: TextStyle(fontSize: 22, color: Color(0xFF8F92A1)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: todayMeds.length,
              itemBuilder: (context, idx) {
                final med = todayMeds[idx];
                final status = getMedicationStatus(med);
                
                return Container(
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF6B7FD7).withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.medication_liquid_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3142),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 22, color: Color(0xFF8F92A1)),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              med.times.join(' • '),
                                              style: TextStyle(
                                                color: Color(0xFF8F92A1),
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (med.notes.isNotEmpty) ...[
                              SizedBox(height: 18),
                              Container(
                                padding: EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 24, color: Color(0xFF6B7FD7)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        med.notes,
                                        style: TextStyle(
                                          color: Color(0xFF5C5F72),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 18),
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                              decoration: BoxDecoration(
                                color: statusBgColor(status),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status == "taken" ? Icons.check_circle_rounded : 
                                    status == "missed" ? Icons.cancel_rounded : Icons.schedule_rounded,
                                    size: 28,
                                    color: statusTextColor(status),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    status == "taken" ? "Taken" : status == "missed" ? "Missed" : "Pending",
                                    style: TextStyle(
                                      color: statusTextColor(status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status == "pending")
                        Container(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => handleStatusChange(med.id, "taken"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF66BB6A),
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 32),
                                      SizedBox(width: 12),
                                      Text(
                                        'Mark as Taken',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => handleStatusChange(med.id, "missed"),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    side: BorderSide(color: Color(0xFFEF5777), width: 3),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cancel_rounded, color: Color(0xFFEF5777), size: 32),
                                      SizedBox(width: 12),
                                      Text(
                                        'Mark as Missed',
                                        style: TextStyle(
                                          color: Color(0xFFEF5777),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: Container(
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6B7FD7).withOpacity(0.4),
              blurRadius: 16,
              offset: Offset(0, 8),
            )
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            resetForm();
            setState(() {
              view = "add";
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.add_rounded, size: 36),
          label: Text(
            'Add Medication',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }

  Widget buildListView() {
    final filteredMeds = medications.where((med) {
      return med.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        leading: Padding(
          padding: EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF6B7FD7), size: 32),
            onPressed: () {
              setState(() {
                view = "today";
              });
            },
          ),
        ),
        title: Text(
          'All Medications',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              style: TextStyle(fontSize: 22, color: Color(0xFF2D3142)),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(fontSize: 22, color: Color(0xFFB0B3C1)),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.search_rounded, size: 36, color: Color(0xFF6B7FD7)),
                ),
                suffixIcon: searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 32, color: Color(0xFFB0B3C1)),
                      onPressed: () => setState(() => searchQuery = ""),
                      padding: EdgeInsets.all(16),
                    )
                  : null,
                filled: true,
                fillColor: Color(0xFFF5F6FA),
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Color(0xFF6B7FD7), width: 3),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredMeds.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Color(0xFFF5F6FA),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              searchQuery.isEmpty ? Icons.medication_rounded : Icons.search_off_rounded,
                              size: 80,
                              color: Color(0xFFB0B3C1),
                            ),
                          ),
                          SizedBox(height: 28),
                          Text(
                            searchQuery.isEmpty 
                              ? 'No Medications'
                              : 'Not Found',
                            style: TextStyle(
                              fontSize: 28,
                              color: Color(0xFF2D3142),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            searchQuery.isEmpty
                              ? 'Press + to add medication'
                              : 'Try different words',
                            style: TextStyle(fontSize: 22, color: Color(0xFF8F92A1)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: filteredMeds.length,
                    itemBuilder: (context, idx) {
                      final med = filteredMeds[idx];
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF6B7FD7).withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Icon(
                                      Icons.medication_liquid_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                  SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          med.name,
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D3142),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 22, color: Color(0xFF8F92A1)),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                med.times.join(' • '),
                                                style: TextStyle(
                                                  color: Color(0xFF8F92A1),
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: Color(0xFFF5F6FA),
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        onTap: () => handleEditClick(med.id),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.edit_rounded, color: Color(0xFF6B7FD7), size: 28),
                                              SizedBox(width: 10),
                                              Text(
                                                'Edit',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF6B7FD7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Material(
                                      color: Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        onTap: () => handleDeleteClick(med.id, med.name),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.delete_rounded, color: Color(0xFFEF5777), size: 28),
                                              SizedBox(width: 10),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFEF5777),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (med.notes.isNotEmpty) ...[
                                SizedBox(height: 18),
                                Container(
                                  padding: EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF5F6FA),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 24, color: Color(0xFF6B7FD7)),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          med.notes,
                                          style: TextStyle(
                                            color: Color(0xFF5C5F72),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6B7FD7).withOpacity(0.4),
              blurRadius: 16,
              offset: Offset(0, 8),
            )
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            resetForm();
            setState(() {
              view = "add";
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.add_rounded, size: 36),
          label: Text(
            'Add Medication',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget buildAddView() {
    final dots = progressDots();
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        leading: Padding(
          padding: EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF6B7FD7), size: 32),
            onPressed: () {
              resetForm();
              setState(() {
                view = "today";
              });
            },
          ),
        ),
        title: Text(
          editingId != null ? 'Edit Medication' : 'Add Medication',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: dots.asMap().entries.map((entry) {
                final active = entry.value;
                return Expanded(
                  child: Container(
                    height: 10,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: active ? LinearGradient(
                        colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
                      ) : null,
                      color: active ? null : Color(0xFFE8E9F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 28),
            Container(
              padding: EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF6B7FD7).withOpacity(0.08),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step == 1) ...[
                    _buildStepHeader('Step 1', 'Enter Medication Name'),
                    SizedBox(height: 24),
                    _buildLabel('Medication Name'),
                    SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => medicineName = v),
                      controller: TextEditingController.fromValue(TextEditingValue(text: medicineName, selection: TextSelection.collapsed(offset: medicineName.length))),
                      style: TextStyle(fontSize: 24, color: Color(0xFF2D3142), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g., Aspirin',
                        hintStyle: TextStyle(fontSize: 24, color: Color(0xFFB0B3C1)),
                        filled: true,
                        fillColor: Color(0xFFF5F6FA),
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Color(0xFF6B7FD7), width: 3),
                        ),
                      ),
                    ),
                    SizedBox(height: 28),
                    _buildPrimaryButton('Next', medicineName.trim().isEmpty ? null : handleNext),
                  ],
                  if (step == 2) ...[
                    _buildStepHeader('Step 2', 'Select Days'),
                    SizedBox(height: 24),
                    Column(
                      children: DAYS.map((day) {
                        final selected = selectedDays.contains(day);
                        return Container(
                          margin: EdgeInsets.only(bottom: 14),
                          child: Material(
                            color: selected ? Color(0xFF6B7FD7).withOpacity(0.1) : Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: () => handleDayToggle(day),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected ? Color(0xFF6B7FD7) : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: selected ? LinearGradient(
                                          colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
                                        ) : null,
                                        color: selected ? null : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: selected ? null : Border.all(color: Color(0xFFE8E9F0), width: 2),
                                      ),
                                      child: selected ? Icon(Icons.check, color: Colors.white, size: 22) : null,
                                    ),
                                    SizedBox(width: 18),
                                    Text(
                                      day,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        color: selected ? Color(0xFF2D3142) : Color(0xFF8F92A1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24),
                    _buildPrimaryButton('Next', selectedDays.isEmpty ? null : handleNext),
                  ],
                  if (step == 3) ...[
                    _buildStepHeader('Step 3', 'How Many Times Per Day?'),
                    SizedBox(height: 24),
                    Column(
                      children: [
                        _freqOption('once', 'Once Daily'),
                        _freqOption('twice', 'Twice Daily'),
                        _freqOption('three', 'Three Times Daily'),
                        _freqOption('custom', 'Custom'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _buildPrimaryButton('Next', handleNext),
                  ],
                  if (step == 4) ...[
                    _buildStepHeader('Step 4', 'Set Times'),
                    SizedBox(height: 12),
                    Text(
                      'Times will adjust automatically when you change one',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8F92A1),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 24),
                    Column(
                      children: List.generate(times.length, (index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Time ${index + 1}'),
                            SizedBox(height: 12),
                            Material(
                              color: Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () => _selectTime(index),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.transparent),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 32, color: Color(0xFF6B7FD7)),
                                      SizedBox(width: 16),
                                      Text(
                                        _timeToString(times[index]),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3142),
                                        ),
                                      ),
                                      Spacer(),
                                      Icon(Icons.arrow_forward_ios_rounded, size: 24, color: Color(0xFF8F92A1)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                        );
                      }),
                    ),
                    _buildPrimaryButton('Next', handleNext),
                  ],
                  if (step == 5) ...[
                    _buildStepHeader('Step 5', 'Add Notes (Optional)'),
                    SizedBox(height: 24),
                    _buildLabel('Notes'),
                    SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController.fromValue(TextEditingValue(text: notes, selection: TextSelection.collapsed(offset: notes.length))),
                      onChanged: (v) => setState(() => notes = v),
                      maxLines: 4,
                      style: TextStyle(fontSize: 22, color: Color(0xFF2D3142), fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'e.g., Take with food',
                        hintStyle: TextStyle(fontSize: 22, color: Color(0xFFB0B3C1)),
                        filled: true,
                        fillColor: Color(0xFFF5F6FA),
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Color(0xFF6B7FD7), width: 3),
                        ),
                      ),
                    ),
                    SizedBox(height: 28),
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF5F6FA), Color(0xFFEEEFF7)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.summarize_rounded, color: Color(0xFF6B7FD7), size: 32),
                              SizedBox(width: 12),
                              Text(
                                'Summary',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          _summaryRow(Icons.medication_liquid_rounded, 'Medication', medicineName),
                          SizedBox(height: 14),
                          _summaryRow(Icons.access_time_rounded, 'Times', times.map((t) => _timeToString(t)).join(", ")),
                          SizedBox(height: 14),
                          _summaryRow(Icons.calendar_today_rounded, 'Days', selectedDays.join(", ")),
                          if (notes.isNotEmpty) ...[
                            SizedBox(height: 14),
                            _summaryRow(Icons.note_rounded, 'Notes', notes),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 28),
                    Column(
                      children: [
                        _buildPrimaryButton(editingId != null ? 'Update Medication' : 'Add Medication', handleAdd),
                        SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              resetForm();
                              setState(() {
                                view = "today";
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              side: BorderSide(color: Color(0xFFE8E9F0), width: 3),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8F92A1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String stepNum, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepNum,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7FD7),
          ),
        ),
        SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C5F72),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: onPressed != null ? LinearGradient(
            colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
          ) : null,
          color: onPressed == null ? Color(0xFFE8E9F0) : null,
          boxShadow: onPressed != null ? [
            BoxShadow(
              color: Color(0xFF6B7FD7).withOpacity(0.4),
              blurRadius: 12,
              offset: Offset(0, 6),
            )
          ] : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: onPressed != null ? Colors.white : Color(0xFFB0B3C1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 26, color: Color(0xFF6B7FD7)),
        SizedBox(width: 14),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 20, color: Color(0xFF5C5F72), height: 1.4),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _freqOption(String value, String label) {
    final active = frequency == value;
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      child: Material(
        color: active ? Color(0xFF6B7FD7).withOpacity(0.1) : Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            setState(() {
              frequency = value;
            });
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? Color(0xFF6B7FD7) : Colors.transparent,
                width: 3,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active ? LinearGradient(
                      colors: [Color(0xFF6B7FD7), Color(0xFF8B9FE8)],
                    ) : null,
                    color: active ? null : Colors.white,
                    border: active ? null : Border.all(color: Color(0xFFE8E9F0), width: 2),
                  ),
                  child: active ? Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ) : null,
                ),
                SizedBox(width: 18),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: active ? Color(0xFF2D3142) : Color(0xFF8F92A1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (view == "today") buildTodayView(),
        if (view == "list") buildListView(),
        if (view == "add") buildAddView(),
        if (showDeleteConfirm)
          Positioned.fill(
            child: GestureDetector(
              onTap: cancelDelete,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 32),
                    padding: EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFEF5777),
                            size: 56,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Delete Medication?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Are you sure you want to delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Color(0xFF5C5F72),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '"$deleteName"?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF2D3142),
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 28),
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: confirmDelete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFEF5777),
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Yes, Delete',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: cancelDelete,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  side: BorderSide(color: Color(0xFFE8E9F0), width: 3),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8F92A1),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
