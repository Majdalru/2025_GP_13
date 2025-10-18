import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ✅ login page to navigate to on logout
import '../Screens/login_page.dart';

// ✅ Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppDrawer extends StatelessWidget {
  final String elderlyName;
  final VoidCallback onLogoutConfirmed;

  const AppDrawer({
    super.key,
    required this.elderlyName,
    required this.onLogoutConfirmed,
  });

  String _displayName(Map<String, dynamic>? data) {
    final first = (data?['firstName'] ?? '').toString().trim();
    final last  = (data?['lastName']  ?? '').toString().trim();
    final email = (data?['email']     ?? '').toString().trim();
    final name  = [first, last].where((s) => s.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Guest');
  }

  String _displayRole(Map<String, dynamic>? data) {
    final role = (data?['role'] ?? '').toString().toLowerCase().trim();
    return role == 'elderly' ? 'Elderly' : 'Caregiver';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

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
            // ===== Header with gradient, reads caregiver name/role from Firestore =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primaryContainer],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),

                  // 👇 بدل النص الثابت، نقرأ من فايرستور بناءً على UID الحالي
                  Expanded(
                    child: user == null
                        ? const _HeaderTexts(
                            name: 'Guest',
                            subtitle: 'Caregiver',
                            isLight: true,
                          )
                        : StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const _HeaderTexts(
                                  name: 'Loading…',
                                  subtitle: '',
                                  isLight: true,
                                );
                              }
                              final data = snap.data?.data();
                              final name = _displayName(data);
                              final role = _displayRole(data);
                              return _HeaderTexts(
                                name: name,
                                subtitle: role,
                                isLight: true,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // ===== عنوان Profiles + زر Add =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Profiles',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddProfileDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),

            // ===== قائمة البروفايلات =====
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _profileTile(context, elderlyName, selected: true),
                  _profileTile(context, 'Elderly 2'),
                  _profileTile(context, 'Elderly 3'),
                ],
              ),
            ),

            // ===== زر تسجيل الخروج =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: () async {
                  final yes = await _confirmLogout(context);
                  if (yes == true) {
                    onLogoutConfirmed();
                    try {
                      await FirebaseAuth.instance.signOut();
                    } finally {
                      // انتقل لصفحة اللوق إن وافرغ الـstack
                      // (rootNavigator: true) لو كان فيه Navigator داخل الـScaffold
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true)
                            .pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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

  // ===== عنصر بروفايل بشكل مودرن =====
  Widget _profileTile(BuildContext context, String name,
      {bool selected = false}) {
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
          name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? cs.primary : null,
          ),
        ),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.chevron_right,
          color: selected ? cs.primary : Colors.black54,
        ),
        onTap: () {
          // TODO: تغيير الـelderly المختار
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to "$name"')),
          );
        },
      ),
    );
  }

  // ===== Dialog إدخال كود (6 خانات) =====
  Future<void> _showAddProfileDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Elderly via Code'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                letterSpacing: 6, fontWeight: FontWeight.w700),
            keyboardType: TextInputType.text,
            inputFormatters: [
              // ✅ حروف وأرقام فقط
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            decoration: const InputDecoration(hintText: '______'),
            validator: (v) => (v?.length == 6) ? null : 'Enter 6 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // TODO: اربطي الكود بإضافة elderly فعليًا
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile code accepted')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ===== تأكيد تسجيل الخروج =====
  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you really want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
  }
}

class _HeaderTexts extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isLight;

  const _HeaderTexts({
    required this.name,
    required this.subtitle,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyle(
      color: isLight ? Colors.white : Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w800,
      fontSize: 16,
    );
    final subStyle = TextStyle(
      color: isLight ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle.isNotEmpty)
          const SizedBox(height: 2),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
