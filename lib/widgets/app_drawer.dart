import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: () async {
                  final yes = await _confirmLogout(context);
                  if (yes == true) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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

  Widget _profileTile(
    BuildContext context,
    String name, {
    bool selected = false,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Switched to "$name"')));
        },
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
            title: const Text('Add Elderly via Code'),
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
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
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
                              const SnackBar(
                                content: Text('Error: You are not logged in.'),
                              ),
                            );
                            setStateInDialog(() => isLoading = false);
                            return;
                          }

                          try {
                            final firestore = FirebaseFirestore.instance;
                            // New Logic: Query the users collection for the code.
                            final querySnapshot = await firestore
                                .collection('users')
                                .where('pairingCode', isEqualTo: enteredCode)
                                .limit(1)
                                .get();

                            if (querySnapshot.docs.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid code.')),
                              );
                            } else {
                              final elderlyDoc = querySnapshot.docs.first;
                              final data = elderlyDoc.data();
                              final elderlyUid = elderlyDoc.id;
                              final createdAt =
                                  (data['pairingCodeCreatedAt'] as Timestamp)
                                      .toDate();

                              // Manual expiration check (client-side)
                              if (DateTime.now()
                                      .difference(createdAt)
                                      .inMinutes >=
                                  2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code has expired.'),
                                  ),
                                );
                                // Invalidate the expired code
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
                                  // Link accounts
                                  transaction.update(caregiverDocRef, {
                                    'elderlyIds': FieldValue.arrayUnion([
                                      elderlyUid,
                                    ]),
                                  });
                                  transaction.update(elderlyDoc.reference, {
                                    'caregiverId': caregiverUid,
                                    // Invalidate code after successful use
                                    'pairingCode': null,
                                    'pairingCodeCreatedAt': null,
                                  });
                                });

                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Profile linked successfully!',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('An error occurred: $e')),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
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
}
