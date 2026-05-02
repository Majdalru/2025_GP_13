import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.elderlyId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final permissions = data['permissions'] as Map<String, dynamic>?;

        if (permissions != null) {
          setState(() {
            _medicationsEnabled = permissions['medications'] ?? true;
            _libraryEnabled = permissions['library'] ?? true;
            _mediaEnabled = permissions['media'] ?? true;
          });
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

  Future<void> _updatePermission(String key, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.elderlyId)
          .set({
        'permissions': {
          key: value,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating permission $key: $e");
      // Revert state if error
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.accessControl),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(
                    AppLocalizations.of(context)!.accessControlDesc,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: AppLocalizations.of(context)!.accessMedications,
                  icon: Icons.medical_services_outlined,
                  value: _medicationsEnabled,
                  color: cs.secondary,
                  onChanged: (val) {
                    setState(() => _medicationsEnabled = val);
                    _updatePermission('medications', val);
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: AppLocalizations.of(context)!.accessLibrary,
                  icon: Icons.wb_sunny_outlined,
                  value: _libraryEnabled,
                  color: cs.primary,
                  onChanged: (val) {
                    setState(() => _libraryEnabled = val);
                    _updatePermission('library', val);
                  },
                ),
                const SizedBox(height: 12),
                _buildPermissionSwitch(
                  title: AppLocalizations.of(context)!.accessMedia,
                  icon: Icons.video_library_outlined,
                  value: _mediaEnabled,
                  color: Colors.teal,
                  onChanged: (val) {
                    setState(() => _mediaEnabled = val);
                    _updatePermission('media', val);
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
