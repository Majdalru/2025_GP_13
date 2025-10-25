import 'dart:async'; // 👈 جديد
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_drawer.dart';
import 'home_page.dart';
import 'browse_page.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import '../medmain.dart';
import '../services/medication_scheduler.dart';

// Model for Elderly Profile data
class ElderlyProfile {
  final String uid;
  final String name;
  ElderlyProfile({required this.uid, required this.name});
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _bottomNavIndex = 0;
  bool _isLoading = true;

  // State for managing multiple elderly profiles
  List<ElderlyProfile> _linkedProfiles = [];
  ElderlyProfile? _selectedProfile;

  // 👇 جديد: اشتراك حي على مستند المستخدم
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _caregiverSub;

  @override
  void initState() {
    super.initState();
    _fetchLinkedProfiles();
    _subscribeToCaregiverDoc(); // 👈 جديد: حدث فوري بعد الربط
    _scheduleNotificationsForUser();
  }

  @override
  void dispose() {
    _caregiverSub?.cancel(); // 👈 مهم: إلغاء الاشتراك
    super.dispose();
  }

  // --- helpers ---
  List<List<T>> _chunk<T>(List<T> items, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      chunks.add(
        items.sublist(i, i + size > items.length ? items.length : i + size),
      );
    }
    return chunks;
  }

  // 👇 جديد: نسمع لأي تغيير على users/{uid} (elderlyIds تتغير بعد الربط)
  void _subscribeToCaregiverDoc() {
    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) return;

    _caregiverSub = FirebaseFirestore.instance
        .collection('users')
        .doc(caregiverUid)
        .snapshots()
        .listen(
          (doc) {
            // كل ما تغير المستند (مثلاً: أضيف elderly جديد) نعيد الجلب
            _fetchLinkedProfiles();
          },
          onError: (e) {
            debugPrint('⚠️ caregiver stream error: $e');
          },
        );
  }

  Future<void> _fetchLinkedProfiles() async {
    setState(() => _isLoading = true);

    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final meRef = FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid);
      final meSnap = await meRef.get();

      final elderlyIds = List<String>.from(
        meSnap.data()?['elderlyIds'] ?? const <String>[],
      );

      debugPrint('🧩 elderlyIds on caregiver $caregiverUid => $elderlyIds');

      if (elderlyIds.isEmpty) {
        setState(() {
          _linkedProfiles = [];
          _selectedProfile = null;
          _isLoading = false;
        });
        return;
      }

      // Firestore whereIn يقبل حتى 10 عناصر — نقسمها دفعات
      final profiles = <ElderlyProfile>[];
      for (final batch in _chunk(elderlyIds, 10)) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final returnedIds = q.docs.map((d) => d.id).toSet();
        for (final missed in batch.where((id) => !returnedIds.contains(id))) {
          debugPrint(
            '⚠️ elderly doc not returned (missing/permission): $missed',
          );
        }

        for (final d in q.docs) {
          try {
            final x = d.data();
            final first = (x['firstName'] ?? '').toString().trim();
            final last = (x['lastName'] ?? '').toString().trim();
            final email = (x['email'] ?? '').toString().trim();
            final name = [first, last].where((s) => s.isNotEmpty).join(' ');
            final display = name.isNotEmpty
                ? name
                : (email.isNotEmpty ? email : 'Unknown');

            profiles.add(ElderlyProfile(uid: d.id, name: display));
            debugPrint('✅ loaded elderly: ${d.id} -> $display');
          } catch (e) {
            debugPrint('❌ error parsing elderly ${d.id}: $e');
          }
        }
      }

      profiles.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() {
        _linkedProfiles = profiles;
        if (_selectedProfile == null ||
            !_linkedProfiles.any((e) => e.uid == _selectedProfile!.uid)) {
          _selectedProfile = _linkedProfiles.isNotEmpty
              ? _linkedProfiles.first
              : null;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching profiles: $e')));
      }
      debugPrint('❗ fetch error: $e');
    }
  }

  void _selectProfile(ElderlyProfile profile) {
    setState(() => _selectedProfile = profile);
    Navigator.pop(context); // Close the drawer
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _selectedProfile != null
          ? HomePage(
              elderlyId: _selectedProfile!.uid, // << أضيفي هذا السطر
              elderlyName: _selectedProfile!.name,
              onTapArrowToMedsSummary: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MedsSummaryPage(
                      elderlyId: _selectedProfile!.uid, // ✅ مرّر الـID
                    ),
                  ),
                );
              },
              onTapArrowToMedmain: () {
                // **NAVIGATION UPDATE**
                // Pass the selected profile to the caregiver's medication page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Medmain(elderlyProfile: _selectedProfile!),
                  ),
                );
              },
              onTapEmergency: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LocationPage()));
              },
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No elderly profile selected.\n\nPlease link a profile using the drawer menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
      BrowsePage(selectedProfile: _selectedProfile),
    ];

    return Scaffold(
      drawer: AppDrawer(
        linkedProfiles: _linkedProfiles,
        selectedProfile: _selectedProfile,
        onProfileSelected: _selectProfile,
        onLogoutConfirmed: () {},
        onProfileLinked: _fetchLinkedProfiles, // يبقى كما هو
      ),
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        elevation: 5.0,

        // (Optional) You can also change the shadow's color
        shadowColor: Colors.black.withOpacity(0.5),

        title: Text(
          _bottomNavIndex == 0
              ? (_selectedProfile?.name ?? 'Dashboard')
              : 'Browse',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: pages[_bottomNavIndex],
            ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          // Sets the color for unselected labels
          textTheme: Theme.of(context).textTheme.copyWith(
            labelSmall: TextStyle(
              color: Colors.grey[700], // Unselected label color
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _bottomNavIndex,
          onDestinationSelected: (i) => setState(() => _bottomNavIndex = i),

          // --- Your Style Properties ---

          // 1. Bar background color
          backgroundColor: const Color.fromARGB(
            69,
            204,
            204,
            208,
          ), // Light gray background
          // 2. "Bubble" indicator color
          indicatorColor: Colors.teal, // Teal bubble
          height: 80,
          elevation: 2, // A subtle shadow
          // --- End Style Properties ---
          destinations: const [
            NavigationDestination(
              // 3. Unselected icon
              icon: Icon(
                Icons.home_outlined,
                color: Colors.grey, // Dark grey for unselected
              ),
              // 4. Selected icon
              selectedIcon: Icon(
                Icons.home,
                color: Colors.white, // White icon on the teal bubble
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps, color: Colors.grey),
              selectedIcon: Icon(Icons.apps_outlined, color: Colors.white),
              label: 'Browse',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scheduleNotificationsForUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // جلب معلومات المستخدم الحالي
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final role = userDoc.data()?['role'] as String?;

      if (role == 'elderly') {
        // إذا كان كبير السن، جدول تنبيهاته
        await MedicationScheduler().scheduleAllMedications(currentUser.uid);
        debugPrint('✅ Scheduled notifications for elderly: ${currentUser.uid}');
      } else if (role == 'caregiver') {
        // إذا كان caregiver، جدول تنبيهات كل الـ elderly المرتبطين به
        final elderlyIds = List<String>.from(
          userDoc.data()?['elderlyIds'] ?? [],
        );

        for (final elderlyId in elderlyIds) {
          await MedicationScheduler().scheduleAllMedications(elderlyId);
          debugPrint('✅ Scheduled notifications for elderly: $elderlyId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error scheduling notifications: $e');
    }
  }
}
