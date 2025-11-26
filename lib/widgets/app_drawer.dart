import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Screens/login_page.dart';
import '../Screens/home_shell.dart'; // Import ElderlyProfile model

class AppDrawer extends StatelessWidget {
  final List<ElderlyProfile> linkedProfiles;
  final ElderlyProfile? selectedProfile;
  final ValueChanged<ElderlyProfile> onProfileSelected;
  final VoidCallback onLogoutConfirmed;
  final VoidCallback onProfileLinked; // Callback to refresh profiles

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

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ===== Header ديناميكي يقرأ من Firestore =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 1, 129, 116),
              ),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: (FirebaseAuth.instance.currentUser == null)
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots(),
                builder: (context, snap) {
                  // القيم الافتراضية
                  String displayName = 'Guest';
                  String roleLabel = 'Caregiver';

                  if (snap.hasData && snap.data!.exists) {
                    final data = snap.data!.data()!;
                    final first = (data['firstName'] ?? '').toString().trim();
                    final last = (data['lastName'] ?? '').toString().trim();
                    final email = (data['email'] ?? '').toString().trim();
                    final role = (data['role'] ?? '').toString().toLowerCase();

                    final name = [first, last]
                        .where((s) => s.isNotEmpty)
                        .join(' ');
                    displayName = name.isNotEmpty
                        ? name
                        : (email.isNotEmpty ? email : 'Guest');
                    roleLabel = (role == 'elderly') ? 'Elderly' : 'Caregiver';
                  }

                  // ← زر الإعدادات
                  return Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
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
                                fontSize: 18, // >=16 لكبار السن
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roleLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(
                          Icons.settings,
                          color: Color.fromARGB(255, 255, 255, 255),
                          size: 30,
                        ),
                        onPressed: () => _openEditDialog(context),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ===== عنوان Linked Profiles + زر Link =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Linked Profiles',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddProfileDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Link'),
                  ),
                ],
              ),
            ),

            // ===== قائمة البروفايلات =====
            Expanded(
              child: linkedProfiles.isEmpty
                  ? const Center(child: Text("No profiles linked yet."))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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

            // ===== زر تسجيل الخروج =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
                  backgroundColor:
                      const Color.fromARGB(255, 255, 193, 190),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
              tooltip: 'Unlink',
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showAddProfileDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateInDialog) {
          bool isLoading = false;
          return AlertDialog(
            title: const Text('Link Elderly via Code'),
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
                validator: (v) =>
                    (v?.length == 6) ? null : 'Enter 6 characters',
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setStateInDialog(() => isLoading = true);
                          final enteredCode =
                              controller.text.trim().toUpperCase();
                          final caregiverUid =
                              FirebaseAuth.instance.currentUser?.uid;

                          if (caregiverUid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error: You are not logged in.'),
                              ),
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
                                const SnackBar(
                                  content: Text('Invalid or expired code.'),
                                ),
                              );
                            } else {
                              final elderlyDoc = querySnapshot.docs.first;
                              final data = elderlyDoc.data();
                              final elderlyUid = elderlyDoc.id;
                              final createdAtTimestamp =
                                  data['pairingCodeCreatedAt'] as Timestamp?;

                              if (createdAtTimestamp == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid code data.'),
                                  ),
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
                                    const SnackBar(
                                      content: Text('Code has expired.'),
                                    ),
                                  );
                                  await elderlyDoc.reference.update({
                                    'pairingCode': null,
                                    'pairingCodeCreatedAt': null,
                                  });
                                } else {
                                  final caregiverDocRef = firestore
                                      .collection('users')
                                      .doc(caregiverUid);

                                  await firestore.runTransaction(
                                    (transaction) async {
                                      transaction.update(caregiverDocRef, {
                                        'elderlyIds': FieldValue.arrayUnion(
                                          [elderlyUid],
                                        ),
                                      });
                                      transaction.update(elderlyDoc.reference, {
                                        'caregiverIds': FieldValue.arrayUnion(
                                          [caregiverUid],
                                        ),
                                        'pairingCode': null,
                                        'pairingCodeCreatedAt': null,
                                      });
                                    },
                                  );

                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Profile linked successfully!'),
                                    ),
                                  );
                                  onProfileLinked();
                                }
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('An error occurred: $e'),
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
                    : const Text('Link'),
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
        title: const Text('Are you sure?'),
        content: const Text('Do you really want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
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
        title: const Text('Delete profile'),
        content: Text(
          'Do you want to Delete ${profile.name} from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
        const SnackBar(content: Text('Error: You are not logged in.')),
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
        SnackBar(content: Text('Profile ${profile.name} unlinked')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unlinking profile: $e')),
      );
    }
  }

  // ===== نافذة تعديل المعلومات (اسم / جنس / جوال) مع التحقق =====
  Future<void> _openEditDialog(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // جلب القيم الحالية لتهيئة الحقول
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
        title: const Text(
          'Edit Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الاسم (إلزامي)
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // الجنس
              DropdownButtonFormField<String>(
                value: genderCtrl.text.isNotEmpty ? genderCtrl.text : null,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (v) => genderCtrl.text = v ?? '',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Select gender' : null,
              ),
              const SizedBox(height: 12),

              // الجوال (05XXXXXXXX)
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile (05XXXXXXXX)',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (v) {
                  final txt = (v ?? '').trim();
                  return RegExp(r'^05\d{8}$').hasMatch(txt)
                      ? null
                      : 'Must start with 05 and be 10 digits';
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final name = nameCtrl.text.trim();
              final parts = name.split(RegExp(r'\s+'));
              final first = parts.isNotEmpty ? parts.first : '';
              final last =
                  parts.length > 1 ? parts.sublist(1).join(' ') : '';

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                'firstName': first,
                'lastName': last,
                'gender': genderCtrl.text,
                'phone': phoneCtrl.text.trim(),
              });

              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Information updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
