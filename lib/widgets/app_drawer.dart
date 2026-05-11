import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Screens/login_page.dart';
import '../Screens/home_shell.dart'; // Import ElderlyProfile model
import 'package:flutter_application_1/l10n/app_localizations.dart';

/// Caregiver Settings Page — previously an AppDrawer, now a full Scaffold page.
/// All logic is identical; only the container changed from Drawer → Scaffold.
class AppDrawer extends StatelessWidget {
  final List<ElderlyProfile> linkedProfiles;
  final ElderlyProfile? selectedProfile;
  final ValueChanged<ElderlyProfile> onProfileSelected;
  final VoidCallback onLogoutConfirmed;
  final VoidCallback onProfileLinked;

  const AppDrawer({
    super.key,
    required this.linkedProfiles,
    required this.selectedProfile,
    required this.onProfileSelected,
    required this.onLogoutConfirmed,
    required this.onProfileLinked,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A2340)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.settings,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2340),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Profile Header Card ──────────────────────────────────
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: (FirebaseAuth.instance.currentUser == null)
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots(),
              builder: (context, snap) {
                String displayName = t.guest;
                String roleLabel = t.caregiverRole;

                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data()!;
                  final first = (data['firstName'] ?? '').toString().trim();
                  final last = (data['lastName'] ?? '').toString().trim();
                  final email = (data['email'] ?? '').toString().trim();
                  final role = (data['role'] ?? '').toString().toLowerCase();

                  final name = [
                    first,
                    last,
                  ].where((s) => s.isNotEmpty).join(' ');
                  displayName = name.isNotEmpty
                      ? name
                      : (email.isNotEmpty ? email : t.guest);
                  roleLabel = (role == 'elderly')
                      ? t.elderlyRole
                      : t.caregiverRole;
                }

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00897B).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: Colors.black87,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roleLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: t.settings,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => _openEditDialog(context),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ── Linked Profiles Header ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_2_outlined,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.linkedProfiles,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF1A2340),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddProfileDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(t.link),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE0F2F1),
                      foregroundColor: const Color(0xFF00897B),
                    ),
                  ),
                ],
              ),
            ),

            // ── Profiles List ────────────────────────────────────────
            Expanded(
              child: linkedProfiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.elderly_outlined,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.noProfilesLinkedYet,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: linkedProfiles.map((profile) {
                        return _profileTile(
                          context,
                          profile,
                          selected: selectedProfile?.uid == profile.uid,
                          onTap: () => onProfileSelected(profile),
                          onDelete: () =>
                              _confirmUnlinkProfile(context, profile),
                        );
                      }).toList(),
                    ),
            ),

            // ── Logout Button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.logout),
                  label: Text(
                    t.logOut,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () async {
                    final yes = await _confirmLogout(context);
                    if (yes == true) {
                      await FirebaseAuth.instance.signOut();
                      onLogoutConfirmed();
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    foregroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== كرت لكل Elderly مع زر حذف =====
  Widget _profileTile(
    BuildContext context,
    ElderlyProfile profile, {
    required bool selected,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: selected ? cs.primary.withOpacity(.08) : null,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.elderly, color: cs.primary),
        ),
        title: Text(
          profile.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? cs.primary : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.chevron_right,
              color: selected ? cs.primary : Colors.black54,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: AppLocalizations.of(context)!.unlink,
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showAddProfileDialog(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateInDialog) {
          bool isLoading = false;
          return AlertDialog(
            title: Text(t.linkElderlyViaCode),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                ],
                decoration: const InputDecoration(
                  hintText: '______',
                  counterText: '',
                ),
                validator: (v) => (v?.length == 6) ? null : t.enter6Characters,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setStateInDialog(() => isLoading = true);
                          final enteredCode = controller.text
                              .trim()
                              .toUpperCase();
                          final caregiverUid =
                              FirebaseAuth.instance.currentUser?.uid;

                          if (caregiverUid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.errorNotLoggedIn)),
                            );
                            setStateInDialog(() => isLoading = false);
                            return;
                          }

                          try {
                            final firestore = FirebaseFirestore.instance;
                            final querySnapshot = await firestore
                                .collection('users')
                                .where('pairingCode', isEqualTo: enteredCode)
                                .limit(1)
                                .get();

                            if (querySnapshot.docs.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(t.invalidOrExpiredCode)),
                              );
                            } else {
                              final elderlyDoc = querySnapshot.docs.first;
                              final data = elderlyDoc.data();
                              final elderlyUid = elderlyDoc.id;
                              final createdAtTimestamp =
                                  data['pairingCodeCreatedAt'] as Timestamp?;

                              if (createdAtTimestamp == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t.invalidCodeData)),
                                );
                                await elderlyDoc.reference.update({
                                  'pairingCode': null,
                                  'pairingCodeCreatedAt': null,
                                });
                              } else {
                                final createdAt = createdAtTimestamp.toDate();
                                if (DateTime.now()
                                        .difference(createdAt)
                                        .inMinutes >=
                                    5) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(t.codeHasExpired)),
                                  );
                                  await elderlyDoc.reference.update({
                                    'pairingCode': null,
                                    'pairingCodeCreatedAt': null,
                                  });
                                } else {
                                  final caregiverDocRef = firestore
                                      .collection('users')
                                      .doc(caregiverUid);

                                  await firestore.runTransaction((
                                    transaction,
                                  ) async {
                                    transaction.update(caregiverDocRef, {
                                      'elderlyIds': FieldValue.arrayUnion([
                                        elderlyUid,
                                      ]),
                                    });
                                    transaction.update(elderlyDoc.reference, {
                                      'caregiverIds': FieldValue.arrayUnion([
                                        caregiverUid,
                                      ]),
                                      'pairingCode': null,
                                      'pairingCodeCreatedAt': null,
                                    });
                                  });

                                  Navigator.pop(ctx);
                                  await _showProfileLinkedDialog(context);
                                  onProfileLinked();
                                }
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.anErrorOccurred(e.toString())),
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setStateInDialog(() => isLoading = false);
                            }
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(t.link),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.areYouSure),
        content: Text(AppLocalizations.of(context)!.doYouReallyWantToLogOut),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.no),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.yes),
          ),
        ],
      ),
    );
  }

  // ===== تأكيد وفك الربط مع Elderly =====
  Future<void> _confirmUnlinkProfile(
    BuildContext context,
    ElderlyProfile profile,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteProfile),
        content: Text(
          AppLocalizations.of(context)!.confirmDeleteProfile(profile.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (yes == true) {
      await _unlinkProfile(context, profile);
    }
  }

  Future<void> _unlinkProfile(
    BuildContext context,
    ElderlyProfile profile,
  ) async {
    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
    if (caregiverUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorNotLoggedIn)),
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

      onProfileLinked(); // تحديث القائمة في الأب
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.profileUnlinked(profile.name),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorUnlinkingProfile(e.toString()),
          ),
        ),
      );
    }
  }

  // ===== نافذة تعديل المعلومات (اسم / جنس / جوال) مع التحقق + منع تكرار الرقم =====
  Future<void> _openEditDialog(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = snap.data() ?? {};
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final gender = (data['gender'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
      text: [first, last].where((s) => s.isNotEmpty).join(' '),
    );
    final genderCtrl = TextEditingController(text: gender);
    final phoneCtrl = TextEditingController(text: phone);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          t.editInfo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: t.name,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? t.nameRequired : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: genderCtrl.text.isNotEmpty ? genderCtrl.text : null,
                decoration: InputDecoration(
                  labelText: t.gender,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'male', child: Text(t.male)),
                  DropdownMenuItem(value: 'female', child: Text(t.female)),
                ],
                onChanged: (v) => genderCtrl.text = v ?? '',
                validator: (v) =>
                    (v == null || v.isEmpty) ? t.selectGender : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: t.mobile,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (v) {
                  final txt = (v ?? '').trim();
                  if (txt.isEmpty) return t.requiredError;
                  if (!txt.startsWith('05')) return t.mustStartWith05;
                  if (txt.length != 10) return t.mustBe10Digits;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final newName = nameCtrl.text.trim();
              final parts = newName.split(RegExp(r'\s+'));
              final firstName = parts.isNotEmpty ? parts.first : '';
              final lastName = parts.length > 1
                  ? parts.sublist(1).join(' ')
                  : '';
              final newGender = genderCtrl.text;
              final newPhone = phoneCtrl.text.trim();

              try {
                if (newPhone != phone) {
                  final dup = await FirebaseFirestore.instance
                      .collection('users')
                      .where('phone', isEqualTo: newPhone)
                      .limit(1)
                      .get();

                  if (dup.docs.isNotEmpty && dup.docs.first.id != uid) {
                    if (ctx.mounted) {
                      await showDialog(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          title: Text(
                            t.mobileInUse,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          content: Text(
                            t.mobileInUseMsg,
                            style: const TextStyle(fontSize: 16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: Text(t.ok),
                            ),
                          ],
                        ),
                      );
                    }
                    return;
                  }
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                      'firstName': firstName,
                      'lastName': lastName,
                      'gender': newGender,
                      'phone': newPhone,
                    });

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t.informationUpdated)));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.errorUpdatingInfo(e.toString()))),
                );
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }

  // ✅ Dialog مخصص ومضبوط على ستايل التطبيق لنجاح ربط البروفايل
  Future<void> _showProfileLinkedDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // دائرة ملونة
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withOpacity(0.12),
                  ),
                  child: Icon(Icons.check_circle, color: cs.primary, size: 60),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Profile linked!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Profile linked successfully. You can now manage this elderly user from your dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
