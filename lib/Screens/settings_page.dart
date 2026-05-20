import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'login_page.dart';

import 'home_shell.dart';
import '../providers/locale_provider.dart';

class SettingsPage extends StatefulWidget {
  final List<ElderlyProfile> linkedProfiles;
  final ElderlyProfile? selectedProfile;
  final ValueChanged<ElderlyProfile> onProfileSelected;
  final VoidCallback onLogoutConfirmed;
  final VoidCallback onProfileLinked;

  const SettingsPage({
    super.key,
    required this.linkedProfiles,
    required this.selectedProfile,
    required this.onProfileSelected,
    required this.onLogoutConfirmed,
    required this.onProfileLinked,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _kNavy = Color(0xFF0D2D5D);
  static const _kTeal = Color(0xFF4DB6AC);

  bool _editingProfile = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _savingProfile = false;
  String _selectedGender = 'male';

  late List<ElderlyProfile> _localLinkedProfiles;
  ElderlyProfile? _localSelectedProfile;

  @override
  void initState() {
    super.initState();
    _localLinkedProfiles = List<ElderlyProfile>.from(widget.linkedProfiles);
    _localSelectedProfile = widget.selectedProfile;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.linkedProfiles != widget.linkedProfiles) {
      _localLinkedProfiles = List<ElderlyProfile>.from(widget.linkedProfiles);
    }

    if (oldWidget.selectedProfile?.uid != widget.selectedProfile?.uid) {
      _localSelectedProfile = widget.selectedProfile;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startEditing(String name, String email, String phone, String gender) {
    _nameCtrl.text = name;
    _emailCtrl.text = email;
    _phoneCtrl.text = phone;
    _selectedGender = gender.isNotEmpty ? gender : 'male';
    setState(() => _editingProfile = true);
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _savingProfile = true);

    final parts = _nameCtrl.text.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'firstName': first,
        'lastName': last,
        'phone': _phoneCtrl.text.trim(),
        'gender': _selectedGender,
      });

      if (mounted) setState(() => _editingProfile = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 26,
                      color: Color(0xFF1A2340),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.settings,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(user, loc, isArabic),
                    const SizedBox(height: 24),
                    _sectionLabel(loc.account),
                    const SizedBox(height: 10),
                    _buildInfoCard(user, loc, isArabic),
                    const SizedBox(height: 22),
                    _sectionLabel(loc.linkedElderly),
                    const SizedBox(height: 10),
                    if (_localLinkedProfiles.isEmpty)
                      _buildEmptyProfiles(loc)
                    else
                      ..._localLinkedProfiles.map(
                        (p) => _buildElderlyProfileTile(context, p),
                      ),
                    const SizedBox(height: 8),
                    _buildAddElderlyButton(context, loc),
                    const SizedBox(height: 22),
                    _sectionLabel(loc.language),
                    const SizedBox(height: 10),
                    _buildLanguageCard(localeProvider, loc, isArabic),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEBEE),
                          foregroundColor: const Color(0xFFD62828),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(
                              color: Color(0xFFFFCDD2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 26),
                        label: Text(
                          loc.logout,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _confirmLogout(context, loc),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _buildCard({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildProfileHeader(User? user, AppLocalizations loc, bool isArabic) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final first = (data?['firstName'] ?? '').toString().trim();
        final last = (data?['lastName'] ?? '').toString().trim();
        final email = (data?['email'] ?? user.email ?? '').toString().trim();
        final name = [first, last].where((s) => s.isNotEmpty).join(' ');
        final initials = [
          if (first.isNotEmpty) first[0],
          if (last.isNotEmpty) last[0],
        ].join().toUpperCase();

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4DB6AC), Color(0xFF00897B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4DB6AC).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : email,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.caregiver,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final phone = (data?['phone'] ?? '').toString().trim();
                    final gender = (data?['gender'] ?? 'male').toString().trim();
                    _startEditing(name, email, phone, gender);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(User? user, AppLocalizations loc, bool isArabic) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data?.data();
        final first = (data?['firstName'] ?? '').toString().trim();
        final last = (data?['lastName'] ?? '').toString().trim();
        final email = (data?['email'] ?? user.email ?? '').toString().trim();
        final phone = (data?['phone'] ?? '').toString().trim();
        final gender = (data?['gender'] ?? '').toString().trim();
        final name = [first, last].where((s) => s.isNotEmpty).join(' ');

        if (_editingProfile) {
          return _buildEditForm(loc, isArabic);
        }

        return _buildCard(
          child: Column(
            children: [
              _infoRow(
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFF00897B),
                iconBg: const Color(0xFFE0F2F1),
                label: loc.name,
                value: name.isNotEmpty ? name : loc.na,
              ),
              _divider(),
              _infoRow(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFF1565C0),
                iconBg: const Color(0xFFE3F2FD),
                label: 'Email',
                value: email.isNotEmpty ? email : loc.na,
              ),
              _divider(),
              _infoRow(
                icon: Icons.phone_outlined,
                iconColor: const Color(0xFFFF8F00),
                iconBg: const Color(0xFFFFF8E1),
                label: loc.mobile,
                value: phone.isNotEmpty ? phone : loc.na,
              ),
              _divider(),
              _infoRow(
                icon: Icons.wc_outlined,
                iconColor: const Color(0xFF7E57C2),
                iconBg: const Color(0xFFEDE7F6),
                label: loc.gender,
                value: gender.isNotEmpty
                    ? (gender == 'male' ? loc.male : loc.female)
                    : loc.na,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        indent: 62,
        color: Colors.grey.shade100,
      );

  Widget _buildEditForm(AppLocalizations loc, bool isArabic) {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'تعديل المعلومات' : 'Edit Information',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2340),
              ),
            ),
            const SizedBox(height: 16),
            _editField(
              controller: _nameCtrl,
              label: loc.name,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 14),
            _editField(
              controller: _phoneCtrl,
              label: loc.mobile,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  _genderOption(isArabic ? 'ذكر' : 'Male', Icons.male, 'male'),
                  _genderOption(isArabic ? 'أنثى' : 'Female', Icons.female, 'female'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: const Color(0xFF1A2340).withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => _editingProfile = false),
                    child: Text(
                      loc.cancel,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A2340),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4DB6AC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _savingProfile ? null : _saveProfile,
                    child: _savingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            loc.save,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderOption(String label, IconData icon, String value) {
    final selected = _selectedGender == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4DB6AC) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF9CA3AF),
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 18,
        color: Color(0xFF1A2340),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF00897B), size: 20),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4DB6AC), width: 2),
        ),
      ),
    );
  }

  Widget _buildElderlyProfileTile(BuildContext context, ElderlyProfile profile) {
    final isSelected = _localSelectedProfile?.uid == profile.uid;
    final loc = AppLocalizations.of(context)!;
    final initials = profile.name.isNotEmpty
        ? profile.name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? _kTeal.withOpacity(0.6) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? _kTeal.withOpacity(0.15) : const Color(0xFFF0F2F5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? _kTeal : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        title: Text(
          profile.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2340),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, color: _kTeal, size: 20),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              tooltip: loc.unlink,
              onPressed: () => _confirmUnlinkProfile(context, profile, loc),
            ),
          ],
        ),
        onTap: () {
          setState(() => _localSelectedProfile = profile);
          widget.onProfileSelected(profile);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmUnlinkProfile(
    BuildContext context,
    ElderlyProfile profile,
    AppLocalizations loc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(loc.deleteProfile),
        content: Text(loc.confirmDeleteProfile(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _unlinkProfile(context, profile, loc);
            },
            child: Text(loc.unlink),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkProfile(
    BuildContext context,
    ElderlyProfile profile,
    AppLocalizations loc,
  ) async {
    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorNotLoggedIn)),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final caregiverDocRef = firestore.collection('users').doc(caregiverUid);
    final elderlyDocRef = firestore.collection('users').doc(profile.uid);

    try {
      await firestore.runTransaction((tx) async {
        tx.update(caregiverDocRef, {
          'elderlyIds': FieldValue.arrayRemove([profile.uid]),
        });
        tx.update(elderlyDocRef, {
          'caregiverIds': FieldValue.arrayRemove([caregiverUid]),
        });
      });

      widget.onProfileLinked();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.profileUnlinked(profile.name)),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorUnlinkingProfile(e.toString())),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Widget _buildEmptyProfiles(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            loc.noLinkedProfiles,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAddElderlyButton(BuildContext context, AppLocalizations loc) {
    return GestureDetector(
      onTap: () => _showLinkDialog(context, loc),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kTeal.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: _kTeal, size: 22),
            const SizedBox(width: 10),
            Text(
              loc.linkNewElderly,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    LocaleProvider localeProvider,
    AppLocalizations loc,
    bool isArabic,
  ) {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.language_outlined,
                color: Color(0xFF00897B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.language,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2340),
                    ),
                  ),
                  Text(
                    isArabic ? 'العربية' : 'English',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => localeProvider.toggleLanguage(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4DB6AC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          Text(
                            'EN',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'ع',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isArabic ? 'ع' : 'EN',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF00897B),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkDialog(BuildContext context, AppLocalizations loc) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(loc.linkNewElderly),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: loc.enterElderlyCode,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _linkElderly(context, controller.text.trim(), loc);
            },
            child: Text(loc.link),
          ),
        ],
      ),
    );
  }

  Future<void> _linkElderly(
    BuildContext context,
    String code,
    AppLocalizations loc,
  ) async {
    final enteredCode = code.trim().toUpperCase();
    if (enteredCode.isEmpty) return;

    final caregiver = FirebaseAuth.instance.currentUser;
    if (caregiver == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorNotLoggedIn),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('pairingCode', isEqualTo: enteredCode)
          .where('role', isEqualTo: 'elderly')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.invalidCode),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
        return;
      }

      final elderlyDoc = snap.docs.first;
      final elderlyId = elderlyDoc.id;
      final elderlyData = elderlyDoc.data();
      final first = (elderlyData['firstName'] ?? '').toString().trim();
      final last = (elderlyData['lastName'] ?? '').toString().trim();
      final email = (elderlyData['email'] ?? '').toString().trim();
      final elderlyName = [first, last].where((s) => s.isNotEmpty).join(' ');
      final displayName = elderlyName.isNotEmpty
          ? elderlyName
          : (email.isNotEmpty ? email : 'Unknown');

      final firestore = FirebaseFirestore.instance;
      final caregiverDocRef = firestore.collection('users').doc(caregiver.uid);
      final elderlyDocRef = firestore.collection('users').doc(elderlyId);

      await firestore.runTransaction((tx) async {
        tx.update(caregiverDocRef, {
          'elderlyIds': FieldValue.arrayUnion([elderlyId]),
        });

        tx.update(elderlyDocRef, {
          'caregiverIds': FieldValue.arrayUnion([caregiver.uid]),
          'pairingCode': FieldValue.delete(),
          'pairingCodeCreatedAt': FieldValue.delete(),
        });
      });

      final newProfile = ElderlyProfile(uid: elderlyId, name: displayName);

      if (mounted) {
        setState(() {
          final exists = _localLinkedProfiles.any((p) => p.uid == elderlyId);
          if (!exists) {
            _localLinkedProfiles = [..._localLinkedProfiles, newProfile]
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
          }
          _localSelectedProfile = newProfile;
        });
      }

      widget.onProfileSelected(newProfile);
      widget.onProfileLinked();

      if (context.mounted) {
        await _showLinkedSuccessDialog(context, displayName);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _showLinkedSuccessDialog(
    BuildContext context,
    String elderlyName,
  ) async {
    final isArabic = Provider.of<LocaleProvider>(context, listen: false).isArabic;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF00897B),
                size: 42,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'تمت الإضافة بنجاح' : 'Added Successfully',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2340),
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'تم إضافة $elderlyName إلى قائمة كبار السن المرتبطين.'
              : '$elderlyName has been added to your linked elderly profiles.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4DB6AC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                isArabic ? 'حسنًا' : 'OK',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(loc.logout),
        content: Text(loc.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              widget.onLogoutConfirmed();

              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: Text(loc.logout),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.trailing,
    this.onTap,
  });
}

class _ChevronTrailing extends StatelessWidget {
  const _ChevronTrailing();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20);
}
