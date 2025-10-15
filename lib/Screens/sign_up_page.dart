import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';        // ✅ Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart';    // ✅ Firestore

import 'home_shell.dart';
import '../elderly_Screens/screens/elderly_home.dart';

enum SignUpRole { caregiver, elderly }

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // ✅ مراجع Firebase
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  SignUpRole _role = SignUpRole.caregiver;

  final _formKey  = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _first    = TextEditingController();
  final _last     = TextEditingController();
  final _phone    = TextEditingController();
  final _email    = TextEditingController();
  final _pass     = TextEditingController();

  String _gender = 'Male';
  bool _ob = true, _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ✅ يربط الزر بـ Auth + Firestore
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 1) إنشاء الحساب في Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      final uid = cred.user!.uid;

      // 2) إنشاء وثيقة المستخدم في Firestore (users/{uid})
      final roleStr = _role == SignUpRole.elderly ? 'elderly' : 'caregiver';

      await _db.collection('users').doc(uid).set({
        'role'      : roleStr,
        'username'  : _username.text.trim().toLowerCase(),
        'firstName' : _first.text.trim(),
        'lastName'  : _last.text.trim(),
        'gender'    : _gender.toLowerCase(), // 'male' / 'female'
        'phone'     : _phone.text.trim(),
        'email'     : _email.text.trim(),
        'photoUrl'  : null,
        'isActive'  : true,
        'createdAt' : FieldValue.serverTimestamp(),
        'updatedAt' : FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // 3) تنقّل حسب الدور
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created ✅')),
      );

      if (_role == SignUpRole.elderly) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ElderlyHomePage()),
          (_) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error';
      if (e.code == 'email-already-in-use') msg = 'Email already in use';
      else if (e.code == 'invalid-email')   msg = 'Invalid email';
      else if (e.code == 'weak-password')   msg = 'Weak password';
      else msg = e.message ?? e.code;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isElderly = _role == SignUpRole.elderly;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: isElderly ? 28 : 24,
    );
    final inputTextStyle = TextStyle(fontSize: isElderly ? 18 : 14);
    final labelStyle = TextStyle(
      fontSize: isElderly ? 16 : 13,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Create an account', style: titleStyle),
          const SizedBox(height: 10),

          // 🔹 اختيار الدور
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _roleChip(
                  'Caregiver',
                  _role == SignUpRole.caregiver,
                  () => setState(() => _role = SignUpRole.caregiver),
                ),
                const SizedBox(width: 8),
                _roleChip(
                  'Elderly',
                  _role == SignUpRole.elderly,
                  () => setState(() => _role = SignUpRole.elderly),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // 🔹 Username
                TextFormField(
                  controller: _username,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // 🔹 First / Last name
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _first,
                        style: inputTextStyle,
                        decoration: InputDecoration(
                          labelText: 'First name',
                          labelStyle: labelStyle,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _last,
                        style: inputTextStyle,
                        decoration: InputDecoration(
                          labelText: 'Last name',
                          labelStyle: labelStyle,
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🔹 Gender
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.wc_outlined),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 🔹 Phone
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'Enter a valid phone'
                      : null,
                ),
                const SizedBox(height: 12),

                // 🔹 Email
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 12),

                // 🔹 Password
                TextFormField(
                  controller: _pass,
                  obscureText: _ob,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _ob = !_ob),
                      icon: Icon(_ob ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🔹 زر إنشاء الحساب
          FilledButton(
            onPressed: _loading
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      _submit();
                    }
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(),
                  )
                : const Text('Create account'),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
