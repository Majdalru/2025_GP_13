import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class ManageAccessPage extends StatefulWidget {
  final String elderlyId;

  const ManageAccessPage({super.key, required this.elderlyId});

  @override
  State<ManageAccessPage> createState() => _ManageAccessPageState();
}

class _ManageAccessPageState extends State<ManageAccessPage> {
  bool _isLoading = true;
  bool _medicationsEnabled = true;
  bool _libraryEnabled = true;
  bool _mediaEnabled = true;
  bool _generateCodeEnabled = true;
  bool _deleteCaregiverEnabled = true;
  Map<String, dynamic>? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final caregiverId = user?.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.elderlyId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        _lastUpdate = data['lastAccessUpdate'] as Map<String, dynamic>?;

        final allCaregiverPerms = data['caregiver_permissions'] as Map<String, dynamic>?;
        final caregiverPerms = (caregiverId != null && allCaregiverPerms != null)
            ? allCaregiverPerms[caregiverId] as Map<String, dynamic>?
            : null;

        if (caregiverPerms != null) {
          setState(() {
            _medicationsEnabled = caregiverPerms['medications'] ?? true;
            _libraryEnabled = caregiverPerms['library'] ?? true;
            _mediaEnabled = caregiverPerms['media'] ?? true;
            _generateCodeEnabled = caregiverPerms['generate_code'] ?? true;
            _deleteCaregiverEnabled = caregiverPerms['delete_caregiver'] ?? true;
          });
        } else {
          final permissions = data['permissions'] as Map<String, dynamic>?;
          if (permissions != null) {
            setState(() {
              _medicationsEnabled = permissions['medications'] ?? true;
              _libraryEnabled = permissions['library'] ?? true;
              _mediaEnabled = permissions['media'] ?? true;
              _generateCodeEnabled = permissions['generate_code'] ?? true;
              _deleteCaregiverEnabled = permissions['delete_caregiver'] ?? true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching permissions: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePermission(String key, bool value, String featureName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final caregiverId = user.uid;

      final caregiverDoc = await FirebaseFirestore.instance.collection('users').doc(caregiverId).get();
      final caregiverName = caregiverDoc.data()?['firstName'] ?? 'A caregiver';

      final updateData = {
        'caregiver_permissions': {
          caregiverId: {
            key: value,
          }
        },
        'lastAccessUpdate': {
          'name': caregiverName,
          'action': value ? 'enabled' : 'disabled',
          'feature': featureName,
          'timestamp': FieldValue.serverTimestamp(),
        }
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.elderlyId)
          .set(updateData, SetOptions(merge: true));
          
      _fetchPermissions();
    } catch (e) {
      debugPrint("Error updating permission $key: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.anErrorOccurred(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
        _fetchPermissions(); // refetch to revert
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.accessControl),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_lastUpdate != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.lastAccessUpdate(
                              _lastUpdate!['name'] ?? '',
                              _lastUpdate!['action'] == 'enabled' ? loc.actionEnabled : loc.actionDisabled,
                              _lastUpdate!['feature'] ?? '',
                            ),
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(
                    loc.accessControlDesc,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: loc.accessMedications,
                  icon: Icons.medical_services_outlined,
                  value: _medicationsEnabled,
                  color: cs.secondary,
                  onChanged: (val) {
                    setState(() => _medicationsEnabled = val);
                    _updatePermission('medications', val, loc.accessMedications);
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: loc.accessLibrary,
                  icon: Icons.wb_sunny_outlined,
                  value: _libraryEnabled,
                  color: cs.primary,
                  onChanged: (val) {
                    setState(() => _libraryEnabled = val);
                    _updatePermission('library', val, loc.accessLibrary);
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: loc.accessMedia,
                  icon: Icons.video_library_outlined,
                  value: _mediaEnabled,
                  color: Colors.teal,
                  onChanged: (val) {
                    setState(() => _mediaEnabled = val);
                    _updatePermission('media', val, loc.accessMedia);
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: loc.accessGenerateCode,
                  icon: Icons.qr_code_2_rounded,
                  value: _generateCodeEnabled,
                  color: Colors.deepPurple,
                  onChanged: (val) {
                    setState(() => _generateCodeEnabled = val);
                    _updatePermission('generate_code', val, loc.accessGenerateCode);
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: loc.accessDeleteCaregiver,
                  icon: Icons.person_remove_outlined,
                  value: _deleteCaregiverEnabled,
                  color: Colors.red,
                  onChanged: (val) {
                    setState(() => _deleteCaregiverEnabled = val);
                    _updatePermission('delete_caregiver', val, loc.accessDeleteCaregiver);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildPermissionSwitch({
    required String title,
    required IconData icon,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          value: value,
          activeColor: color,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
