import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:audioplayers/audioplayers.dart';

import 'home_page.dart';
import 'browse_page.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import 'settings_page.dart';
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
  String? _caregiverName; // for greeting

  final Set<String> _shownAlertDialogs = {};
  final AudioPlayer _emergencyPlayer = AudioPlayer();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _kNavy = Color(0xFF102E50);
  static const _kTeal = Color(0xFF4E949C);

  @override
  void initState() {
    super.initState();
    _fetchLinkedProfiles();
    _fetchCaregiverName();
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

  // ── Caregiver name for greeting ───────────────────────────────────────────
  Future<void> _fetchCaregiverName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    final first = (data['firstName'] ?? '').toString().trim();
    if (mounted && first.isNotEmpty) {
      setState(() => _caregiverName = first);
    }
  }

  // ── Greeting ──────────────────────────────────────────────────────────────
  String _greeting(AppLocalizations loc) {
    final hour = DateTime.now().hour;
    if (hour < 12) return loc.goodMorning;
    if (hour < 17) return loc.goodAfternoon;
    return loc.goodEvening;
  }

  // ── Emergency sound ───────────────────────────────────────────────────────
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

  // ── SOS listener ─────────────────────────────────────────────────────────
  void _listenToEmergencyAlerts() {
    _emergencySub = FirebaseFirestore.instance
        .collection('emergency_alerts')
        .where('status', whereIn: ['active', 'seen'])
        .snapshots()
        .listen(
      (snapshot) async {
        final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
        if (caregiverUid == null) return;

        final caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverUid)
            .get();

        final linkedIds = List<String>.from(
          caregiverDoc.data()?['elderlyIds'] ?? [],
        );

        final linkedAlerts = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final elderlyId = data['elderlyId']?.toString();
          return elderlyId != null && linkedIds.contains(elderlyId);
        }).toList();

        linkedAlerts.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'];
          final bTime = bData['createdAt'];

          DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);

          if (aTime is Timestamp) {
            aDate = aTime.toDate();
          }

          if (bTime is Timestamp) {
            bDate = bTime.toDate();
          }

          return bDate.compareTo(aDate); // newest first
        });

        if (!mounted) return;

        if (linkedAlerts.isEmpty) {
          await _stopEmergencySound();

          setState(() {
            _activeAlertId = null;
            _activeAlertElderlyId = null;
            _activeAlertElderlyName = null;
          });
          return;
        }

        final latestAlert = linkedAlerts.first;
        final data = latestAlert.data() as Map<String, dynamic>;

        final elderlyId = data['elderlyId']?.toString() ?? '';
        final elderlyName = data['elderlyName']?.toString() ?? 'Elderly';
        final alertStatus = data['status']?.toString() ?? 'active';

        setState(() {
          _activeAlertId = latestAlert.id;
          _activeAlertElderlyId = elderlyId;
          _activeAlertElderlyName = elderlyName;
        });

        // Only play sound and show popup for a new ACTIVE alert.
        // Seen alerts keep the banner visible but do not replay the sound.
        if (alertStatus == 'active' &&
            !_shownAlertDialogs.contains(latestAlert.id)) {
          _shownAlertDialogs.add(latestAlert.id);

          await _playEmergencySound();

          await _showEmergencyLocalNotification(
            elderlyName: elderlyName,
            elderlyId: elderlyId,
          );

          _showEmergencyDialog(
            alertId: latestAlert.id,
            elderlyId: elderlyId,
            elderlyName: elderlyName,
          );
        }
      },
      onError: (e) {
        debugPrint('❌ Emergency listener error: $e');
      },
    );
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Alert', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
          '$elderlyName needs help!\nOpen location now.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _stopEmergencySound();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Dismiss'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('emergency_alerts')
                  .doc(alertId)
                  .update({
                    'status': 'seen',
                    'seenAt': FieldValue.serverTimestamp(),
                  });
              await _stopEmergencySound();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationPage(elderlyId: elderlyId),
                ),
              );
            },
            child: const Text('View Location'),
          ),
        ],
      ),
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
      builder: (context) => AlertDialog(
        title: const Text('Confirm Safety'),
        content: const Text(
          'Are you sure the danger is gone and the elderly is safe?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, safe'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _markEmergencyInactive();
  }

  // ── Emergency banner ──────────────────────────────────────────────────────
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
                  'Active Emergency: ${_activeAlertElderlyName ?? 'Elderly'}',
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
            'An emergency alert is currently active.',
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
                    if (_activeAlertId != null) {
                      await FirebaseFirestore.instance
                          .collection('emergency_alerts')
                          .doc(_activeAlertId)
                          .update({
                            'status': 'seen',
                            'seenAt': FieldValue.serverTimestamp(),
                          });
                    }
                    await _stopEmergencySound();
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LocationPage(elderlyId: _activeAlertElderlyId!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('View Location'),
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
                  label: const Text('Danger is gone'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Fetch profiles ────────────────────────────────────────────────────────
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
      final elderlyIds = List<String>.from(meSnap.data()?['elderlyIds'] ?? []);
      final profiles = <ElderlyProfile>[];
      for (final id in elderlyIds) {
        final d = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        final x = d.data() ?? {};
        final name = '${x['firstName'] ?? ''} ${x['lastName'] ?? ''}'.trim();
        profiles.add(ElderlyProfile(uid: id, name: name));
      }
      setState(() {
        _linkedProfiles = profiles;
        _selectedProfile = profiles.isNotEmpty ? profiles.first : null;
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
  }

  // ── Elderly chip initials ─────────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.split(' ').where((w) => w.isNotEmpty).take(2).toList();
    return parts.map((w) => w[0].toUpperCase()).join();
  }

  // ── Top bar (inline, no AppBar — matches elderly home style) ─────────────
  Widget _buildTopBar(AppLocalizations loc) {
    final greet = _greeting(loc);
    final name = _caregiverName ?? '';
    final profile = _selectedProfile;

    return Container(
      color: const Color(0xFFF7F8FA),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: greeting + settings ───────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greet,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF4DB6AC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      name.isNotEmpty ? name : loc.caregiver,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                  ],
                ),
              ),
              // Settings icon
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      linkedProfiles: _linkedProfiles,
                      selectedProfile: _selectedProfile,
                      onProfileSelected: _selectProfile,
                      onLogoutConfirmed: () {},
                      onProfileLinked: _fetchLinkedProfiles,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 34,
                  color: Color(0xFF1A2340),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Row 2: managing chip (wider, bigger) ─────────────────
          if (profile != null)
            GestureDetector(
              onTap: () => _showProfileSwitcher(loc),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4DB6AC), Color(0xFF00897B)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4DB6AC).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _initials(profile.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.managing,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_linkedProfiles.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loc.change,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.expand_more,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    linkedProfiles: _linkedProfiles,
                    selectedProfile: _selectedProfile,
                    onProfileSelected: _selectProfile,
                    onLogoutConfirmed: () {},
                    onProfileLinked: _fetchLinkedProfiles,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_add_outlined,
                      color: Color(0xFF4DB6AC),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.linkNewElderly,
                      style: const TextStyle(
                        color: Color(0xFF4DB6AC),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // kept for compatibility — returns null so Scaffold uses no AppBar
  PreferredSizeWidget? _buildAppBar(AppLocalizations loc) => null;

  // ── Profile switcher
  void _showProfileSwitcher(AppLocalizations loc) {
    if (_linkedProfiles.length <= 1) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.selectProfile,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ..._linkedProfiles.map((p) {
              final isSelected = _selectedProfile?.uid == p.uid;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? _kTeal
                      : const Color(0xFFF0F2F5),
                  child: Text(
                    _initials(p.name),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: _kTeal)
                    : null,
                onTap: () {
                  _selectProfile(p);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final pages = [
      _selectedProfile != null
          ? HomePage(
              elderlyId: _selectedProfile!.uid,
              elderlyName: _selectedProfile!.name,
              onTapArrowToMedsSummary: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MedsSummaryPage(elderlyId: _selectedProfile!.uid),
                ),
              ),
              onTapArrowToMedmain: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Medmain(elderlyProfile: _selectedProfile!),
                ),
              ),
              onTapEmergency: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LocationPage(elderlyId: _selectedProfile!.uid),
                ),
              ),
            )
          : Center(child: Text(loc.noProfileSelected)),
      BrowsePage(selectedProfile: _selectedProfile),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTopBar(loc),
                _buildEmergencyBanner(),
                Expanded(child: pages[_bottomNavIndex]),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (i) => setState(() => _bottomNavIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: loc.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.apps_outlined),
            selectedIcon: const Icon(Icons.apps),
            label: loc.browse,
          ),
        ],
      ),
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────
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
