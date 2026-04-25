import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:audioplayers/audioplayers.dart';

import '../widgets/app_drawer.dart';
import 'home_page.dart';
import 'browse_page.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import '../medmain.dart';
import '../services/medication_scheduler.dart';
import '../services/notification_service.dart';

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

  List<ElderlyProfile> _linkedProfiles = [];
  ElderlyProfile? _selectedProfile;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _caregiverSub;
  StreamSubscription<QuerySnapshot>? _emergencySub;

  String? _activeAlertId;
  String? _activeAlertElderlyId;
  String? _activeAlertElderlyName;

  final Set<String> _shownAlertDialogs = {};
  final AudioPlayer _emergencyPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _fetchLinkedProfiles();
    _subscribeToCaregiverDoc();
    _scheduleNotificationsForUser();
    _listenToEmergencyAlerts();
  }

  @override
  void dispose() {
    _caregiverSub?.cancel();
    _emergencySub?.cancel();
    _emergencyPlayer.stop();
    _emergencyPlayer.dispose();
    super.dispose();
  }

  Future<void> _playEmergencySound() async {
    try {
      await _emergencyPlayer.stop();
      await _emergencyPlayer.setReleaseMode(ReleaseMode.loop);
      await _emergencyPlayer.play(AssetSource('sounds/emergency.wav'));
    } catch (e) {
      debugPrint('❌ Error playing emergency sound: $e');
    }
  }

  Future<void> _stopEmergencySound() async {
    try {
      await _emergencyPlayer.stop();
    } catch (e) {
      debugPrint('❌ Error stopping emergency sound: $e');
    }
  }

  Future<void> _showEmergencyLocalNotification({
    required String elderlyName,
    required String elderlyId,
  }) async {
    await NotificationService().showEmergencyNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      elderlyName: elderlyName,
      elderlyId: elderlyId,
    );
  }

  // =========================
  // 🚨 SOS LISTENER
  // =========================
  void _listenToEmergencyAlerts() {
    _emergencySub = FirebaseFirestore.instance
        .collection('emergency_alerts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) async {
      final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
      if (caregiverUid == null) return;

      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      final linkedIds = List<String>.from(
        caregiverDoc.data()?['elderlyIds'] ?? [],
      );

      QueryDocumentSnapshot? activeDoc;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final elderlyId = data['elderlyId']?.toString();

        if (elderlyId != null && linkedIds.contains(elderlyId)) {
          activeDoc = doc;
          break;
        }
      }

      if (!mounted) return;

      if (activeDoc == null) {
        await _stopEmergencySound();

        setState(() {
          _activeAlertId = null;
          _activeAlertElderlyId = null;
          _activeAlertElderlyName = null;
        });
        return;
      }

      final data = activeDoc.data() as Map<String, dynamic>;
      final elderlyId = data['elderlyId']?.toString() ?? '';
      final elderlyName = data['elderlyName']?.toString() ?? 'Elderly';

      setState(() {
        _activeAlertId = activeDoc!.id;
        _activeAlertElderlyId = elderlyId;
        _activeAlertElderlyName = elderlyName;
      });

      // Show popup + local notification + emergency sound only once for each new alert.
      if (!_shownAlertDialogs.contains(activeDoc.id)) {
        _shownAlertDialogs.add(activeDoc.id);

        await _playEmergencySound();

        await _showEmergencyLocalNotification(
          elderlyName: elderlyName,
          elderlyId: elderlyId,
        );

        _showEmergencyDialog(
          alertId: activeDoc.id,
          elderlyId: elderlyId,
          elderlyName: elderlyName,
        );
      }
    });
  }

  void _showEmergencyDialog({
    required String alertId,
    required String elderlyId,
    required String elderlyName,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                "Emergency Alert",
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          content: Text(
            "$elderlyName needs help!\nOpen location now.",
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _stopEmergencySound();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Dismiss"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                await _stopEmergencySound();

                if (!context.mounted) return;
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPage(
                      elderlyId: elderlyId,
                    ),
                  ),
                );
              },
              child: const Text("View Location"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markEmergencyInactive() async {
    final alertId = _activeAlertId;

    if (alertId == null) return;

    await FirebaseFirestore.instance
        .collection('emergency_alerts')
        .doc(alertId)
        .update({
      'status': 'inactive',
      'endedAt': FieldValue.serverTimestamp(),
    });

    await _stopEmergencySound();

    if (!mounted) return;

    setState(() {
      _activeAlertId = null;
      _activeAlertElderlyId = null;
      _activeAlertElderlyName = null;
    });
  }

  Future<void> _confirmDangerResolved() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Safety"),
          content: const Text(
            "Are you sure the danger is gone and the elderly is safe?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes, safe"),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _markEmergencyInactive();
    }
  }

  Widget _buildEmergencyBanner() {
    if (_activeAlertId == null || _activeAlertElderlyId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Active Emergency: ${_activeAlertElderlyName ?? 'Elderly'}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "An emergency alert is currently active.",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: () async {
                    await _stopEmergencySound();

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationPage(
                          elderlyId: _activeAlertElderlyId!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text("View Location"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _confirmDangerResolved,
                  icon: const Icon(Icons.check_circle),
                  label: const Text("Danger is gone"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // 📦 FETCH PROFILES
  // =========================
  Future<void> _fetchLinkedProfiles() async {
    setState(() => _isLoading = true);

    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final meSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      final elderlyIds =
          List<String>.from(meSnap.data()?['elderlyIds'] ?? []);

      final profiles = <ElderlyProfile>[];

      for (final id in elderlyIds) {
        final d = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();

        final x = d.data() ?? {};
        final name =
            "${x['firstName'] ?? ''} ${x['lastName'] ?? ''}".trim();

        profiles.add(ElderlyProfile(uid: id, name: name));
      }

      setState(() {
        _linkedProfiles = profiles;
        _selectedProfile =
            profiles.isNotEmpty ? profiles.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToCaregiverDoc() {
    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) return;

    _caregiverSub = FirebaseFirestore.instance
        .collection('users')
        .doc(caregiverUid)
        .snapshots()
        .listen((_) => _fetchLinkedProfiles());
  }

  void _selectProfile(ElderlyProfile profile) {
    setState(() => _selectedProfile = profile);
    Navigator.pop(context);
  }

  // =========================
  // 🧠 UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final pages = [
      _selectedProfile != null
          ? HomePage(
              elderlyId: _selectedProfile!.uid,
              elderlyName: _selectedProfile!.name,

              onTapArrowToMedsSummary: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MedsSummaryPage(
                      elderlyId: _selectedProfile!.uid,
                    ),
                  ),
                );
              },

              onTapArrowToMedmain: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Medmain(
                      elderlyProfile: _selectedProfile!,
                    ),
                  ),
                );
              },

              onTapEmergency: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPage(
                      elderlyId: _selectedProfile!.uid,
                    ),
                  ),
                );
              },
            )
          : const Center(child: Text("No profile selected")),

      BrowsePage(selectedProfile: _selectedProfile),
    ];

    return Scaffold(
      drawer: AppDrawer(
        linkedProfiles: _linkedProfiles,
        selectedProfile: _selectedProfile,
        onProfileSelected: _selectProfile,
        onLogoutConfirmed: () {},
        onProfileLinked: _fetchLinkedProfiles,
      ),
      appBar: AppBar(
        title: Text(
          _bottomNavIndex == 0 ? "Home" : "Browse",
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildEmergencyBanner(),
                Expanded(
                  child: pages[_bottomNavIndex],
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (i) =>
            setState(() => _bottomNavIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home), label: "Home"),
          NavigationDestination(
              icon: Icon(Icons.apps), label: "Browse"),
        ],
      ),
    );
  }

  // =========================
  // 🔔 (اختياري)
  // =========================
  Future<void> _scheduleNotificationsForUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final role = userDoc.data()?['role'] as String?;

      if (role == 'elderly') {
        await MedicationScheduler().scheduleAllMedications(currentUser.uid);
      } else if (role == 'caregiver') {
        final elderlyIds = List<String>.from(
          userDoc.data()?['elderlyIds'] ?? [],
        );

        for (final elderlyId in elderlyIds) {
          await MedicationScheduler().scheduleAllMedications(elderlyId);
        }
      }
    } catch (_) {}
  }
}
