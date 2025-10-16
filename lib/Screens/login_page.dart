import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'forgot_password_page.dart';
import 'sign_up_page.dart';          // ✅ صفحة تسجيل الـ Caregiver
import 'elderly_sign_up_page.dart'; // ✅ صفحة تسجيل الـ Elderly
import 'home_shell.dart';
import '../../elderly_Screens/screens/elderly_home.dart';

enum UserRole { caregiver, elderly }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  UserRole _role = UserRole.caregiver;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _ob = true, _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _prettyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'No user found for this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'invalid-email':  return 'Invalid email address.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      case 'user-disabled':  return 'This account has been disabled.';
      case 'network-request-failed': return 'Network error. Check your internet connection.';
      default: return e.message ?? 'Unexpected error occurred.';
    }
  }

  void _showNiceSnack({
    required String title,
    required String message,
    bool success = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = success ? cs.primary : Colors.red.shade600;
    final ic = success ? Icons.check_circle : Icons.error_rounded;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: bg,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ic, size: 22, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final email    = _email.text.trim();
      final password = _pass.text.trim();

      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        _showNiceSnack(title: 'Invalid email', message: 'Enter a valid email address.');
        return;
      }

      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      final profile = await _db.collection('users').doc(uid).get();
      final role = (profile.data()?['role'] ?? 'caregiver') as String;

      if (!mounted) return;

      _role = role == 'elderly' ? UserRole.elderly : UserRole.caregiver;

      _showNiceSnack(title: 'Success', message: 'Logged in successfully.', success: true);

      if (role == 'elderly') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ElderlyHomePage()));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeShell()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showNiceSnack(title: 'Couldn’t sign in', message: _prettyAuthError(e));
    } catch (e) {
      if (mounted) _showNiceSnack(title: 'Error', message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final w    = size.width;

    const maxContentWidth = 480.0;
    final logoH = (w * 0.22).clamp(80, 140);
    final isElderly = _role == UserRole.elderly;

    final titleStyle      = TextStyle(fontWeight: FontWeight.w900, fontSize: isElderly ? 30 : 24);
    final inputTextStyle  = TextStyle(fontSize: isElderly ? 18 : 15);
    final labelStyle      = TextStyle(fontSize: isElderly ? 16 : 13, fontWeight: FontWeight.w600);
    const fieldPadding    = EdgeInsets.symmetric(vertical: 18, horizontal: 14);
    final  buttonStyle    = FilledButton.styleFrom(minimumSize: const Size.fromHeight(56),
                               textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.asset('assets/khalil_logo.png',
                      height: logoH.toDouble(), width: logoH.toDouble(), fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),

                Center(child: Text('Log in', style: titleStyle)),
                const SizedBox(height: 14),

                // Role chips (visual toggle)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _roleChip('Caregiver', _role == UserRole.caregiver,
                          () => setState(() => _role = UserRole.caregiver)),
                      const SizedBox(width: 8),
                      _roleChip('Elderly', _role == UserRole.elderly,
                          () => setState(() => _role = UserRole.elderly)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: inputTextStyle,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: labelStyle,
                          prefixIcon: const Icon(Icons.email_outlined),
                          contentPadding: fieldPadding,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
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
                          contentPadding: fieldPadding,
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ForgotPasswordPage()),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),

                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: buttonStyle,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator())
                      : const Text('Next'),
                ),

                const SizedBox(height: 16),

                // ⬇️ فتح صفحة التسجيل الصحيحة حسب الدور
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don’t have an account?", style: TextStyle(color: Colors.grey.shade700)),
                    TextButton(
                      onPressed: () {
                        if (_role == UserRole.elderly) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ElderlySignUpPage()),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SignUpPage()),
                          );
                        }
                      },
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
          height: 44,
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
