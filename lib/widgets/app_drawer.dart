import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ✅ أضيفي هذا الاستيراد
import '../Screens/login_page.dart';


class AppDrawer extends StatelessWidget {
  final String elderlyName;
  final VoidCallback onLogoutConfirmed;

  const AppDrawer({
    super.key,
    required this.elderlyName,
    required this.onLogoutConfirmed,
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
            // ===== Header بشريط جذاب =====
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guest',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Caregiver',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
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
                    // (اختياري) نادِ الكولباك لو عندك تنظيف حالة
                    onLogoutConfirmed();

                    // ✅ ننتقل لصفحة اللوق إن ونمسح المكدس
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  Widget _profileTile(BuildContext context, String name, {bool selected = false}) {
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

  // ===== Dialog إدخال كود (4 خانات) =====
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
            style: const TextStyle(letterSpacing: 6, fontWeight: FontWeight.w700),
            keyboardType: TextInputType.text,
inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), // ✅ حروف وأرقام
          ],            decoration: const InputDecoration(hintText: '______'),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
  }
}
