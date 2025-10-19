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

  Future<void> _fetchLinkedProfiles() async {
    setState(() => _isLoading = true);
    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) {
      // Handle user not being logged in
      setState(() => _isLoading = false);
      return;
    }

    try {
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      final elderlyIds = List<String>.from(
        caregiverDoc.data()?['elderlyIds'] ?? [],
      );

      if (elderlyIds.isEmpty) {
        setState(() {
          _linkedProfiles = [];
          _selectedProfile = null;
          _isLoading = false;
        });
        return;
      }

      // Fetch profile for each elderly ID
      List<ElderlyProfile> profiles = [];
      for (String id in elderlyIds) {
        final elderlyDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (elderlyDoc.exists) {
          profiles.add(
            ElderlyProfile(
              uid: id,
              name: '${elderlyDoc['firstName']} ${elderlyDoc['lastName']}',
            ),
          );
        }
      }

      setState(() {
        _linkedProfiles = profiles;
        // Set the first profile as selected by default, if any exist
        _selectedProfile = profiles.isNotEmpty ? profiles.first : null;
        _isLoading = false;
      });
    } catch (e) {
      // Handle errors, e.g., show a snackbar
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching profiles: $e')));
    }
  }

  void _selectProfile(ElderlyProfile profile) {
    setState(() {
      _selectedProfile = profile;
    });
    Navigator.pop(context); // Close the drawer
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // Pass the selected profile to HomePage
      _selectedProfile != null
          ? HomePage(
              elderlyName: _selectedProfile!.name,
              onTapArrowToMedsSummary: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MedsSummaryPage()),
              ),
              onTapArrowToMedmain: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const Medmain())),
              onTapEmergency: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LocationPage())),
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
        // Pass the full list and selected profile to the drawer
        linkedProfiles: _linkedProfiles,
        selectedProfile: _selectedProfile,
        onProfileSelected: _selectProfile,
        onLogoutConfirmed: () {
          // This part is handled by the drawer itself now
        },
        onProfileLinked:
            _fetchLinkedProfiles, // Callback to refresh profiles after linking
      ),
      appBar: AppBar(
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
