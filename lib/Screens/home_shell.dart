import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_drawer.dart';
import 'home_page.dart';
import 'browse_page.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import '../medmain.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchLinkedProfiles();
  }

  // --- helpers ---
  List<List<T>> _chunk<T>(List<T> items, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      chunks.add(items.sublist(i, i + size > items.length ? items.length : i + size));
    }
    return chunks;
  }

  Future<void> _fetchLinkedProfiles() async {
    setState(() => _isLoading = true);

    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final meRef = FirebaseFirestore.instance.collection('users').doc(caregiverUid);
      final meSnap = await meRef.get();

      final elderlyIds = List<String>.from(meSnap.data()?['elderlyIds'] ?? const <String>[]);

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

        // علشان لو في ID ما رجع (غير موجود/مرفوض) نطبع سطر عنه
        final returnedIds = q.docs.map((d) => d.id).toSet();
        for (final missed in batch.where((id) => !returnedIds.contains(id))) {
          debugPrint('⚠️ elderly doc not returned (missing/permission): $missed');
        }

        for (final d in q.docs) {
          try {
            final x = d.data();
            final first = (x['firstName'] ?? '').toString().trim();
            final last  = (x['lastName']  ?? '').toString().trim();
            final email = (x['email']     ?? '').toString().trim();
            final name  = [first, last].where((s) => s.isNotEmpty).join(' ');
            final display = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Unknown');

            profiles.add(ElderlyProfile(uid: d.id, name: display));
            debugPrint('✅ loaded elderly: ${d.id} -> $display');
          } catch (e) {
            debugPrint('❌ error parsing elderly ${d.id}: $e');
          }
        }
      }

      // رتّبيهم اختياريًا
      profiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _linkedProfiles = profiles;
        // احتفظ بالمختار إن كان لسه موجود، وإلا أول واحد
        if (_selectedProfile == null || !_linkedProfiles.any((e) => e.uid == _selectedProfile!.uid)) {
          _selectedProfile = _linkedProfiles.isNotEmpty ? _linkedProfiles.first : null;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profiles: $e')),
      );
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
              elderlyName: _selectedProfile!.name,
              onTapArrowToMedsSummary: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MedsSummaryPage()),
                );
              },
              onTapArrowToMedmain: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const Medmain()),
                );
              },
              onTapEmergency: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocationPage()),
                );
              },
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No elderly profile linked. Please link a profile using the drawer menu.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      const BrowsePage(),
    ];

    return Scaffold(
      drawer: AppDrawer(
        linkedProfiles: _linkedProfiles,
        selectedProfile: _selectedProfile,
        onProfileSelected: _selectProfile,
        onLogoutConfirmed: () {},
        // بعد الربط من الدروار رجّعي تحميل القائمة
        onProfileLinked: _fetchLinkedProfiles,
      ),
      appBar: AppBar(
        title: Text(_bottomNavIndex == 0
            ? (_selectedProfile?.name ?? 'Dashboard')
            : 'Browse'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: pages[_bottomNavIndex],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (i) => setState(() => _bottomNavIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps),
            selectedIcon: Icon(Icons.apps_outlined),
            label: 'Browse',
          ),
        ],
      ),
    );
  }
}
