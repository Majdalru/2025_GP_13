import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';          // ✅ Auth
import 'package:cloud_firestore/cloud_firestore.dart';      // ✅ Firestore

import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import 'home_shell.dart';
import '../../elderly_Screens/screens/elderly_home.dart';

enum UserRole { caregiver, elderly }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ✅ Firebase refs
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  UserRole _role = UserRole.caregiver;

  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController(); // email or username
  final _pass = TextEditingController();
  bool _ob = true, _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ---------- Pretty errors & nice snack ----------
  String _prettyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Unexpected error occurred.';
    }
  }

  void _showNiceSnack({
    required String title,
    required String message,
    bool success = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg  = success ? cs.primary : Colors.red.shade600;
    final ic  = success ? Icons.check_circle : Icons.error_rounded;

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
                  Text(title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  // ------------------------------------------------

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final input = _user.text.trim();
      final password = _pass.text.trim();

      // 1) Resolve email (directly, or via username -> email)
      String? email;
      Map<String, dynamic>? userDocData;

      if (input.contains('@')) {
        email = input;
      } else {
        // Lookup by username in users
        final snap = await _db
            .collection('users')
            .where('username', isEqualTo: input.toLowerCase())
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'No user for this username');
        }
        userDocData = snap.docs.first.data();
        email = (userDocData['email'] as String?)?.trim();
        if (email == null || email.isEmpty) {
          throw FirebaseAuthException(
              code: 'invalid-email', message: 'Invalid email on profile');
        }
      }

      // 2) Sign in
      final cred = await _auth.signInWithEmailAndPassword(
        email: email!,
        password: password,
      );
      final uid = cred.user!.uid;

      // 3) Get role for routing
      String role;
      if (userDocData != null) {
        role = (userDocData['role'] ?? 'caregiver') as String;
      } else {
        final profile = await _db.collection('users').doc(uid).get();
        role = (profile.data()?['role'] ?? 'caregiver') as String;
      }

      if (!mounted) return;

      // Optional: sync the chips with the actual role
      _role = role == 'elderly' ? UserRole.elderly : UserRole.caregiver;

      _showNiceSnack(
        title: 'Success',
        message: 'Logged in successfully.',
        success: true,
      );

      // 4) Route
      if (role == 'elderly') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ElderlyHomePage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = _prettyAuthError(e);
      if (mounted) {
        _showNiceSnack(title: 'Couldn’t sign in', message: msg);
      }
    } catch (e) {
      if (mounted) {
        _showNiceSnack(title: 'Error', message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final w = size.width;

    const maxContentWidth = 480.0;
    final logoH = (w * 0.22).clamp(80, 140);
    final isElderly = _role == UserRole.elderly;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: isElderly ? 30 : 24,
    );
    final inputTextStyle = TextStyle(fontSize: isElderly ? 18 : 15);
    final labelStyle = TextStyle(
      fontSize: isElderly ? 16 : 13,
      fontWeight: FontWeight.w600,
    );

    const fieldContentPadding =
        EdgeInsets.symmetric(vertical: 18, horizontal: 14);
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // LOGO
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.asset(
                      'assets/khalil_logo.png',
                      height: logoH.toDouble(),
                      width: logoH.toDouble(),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Center(child: Text('Log in', style: titleStyle)),
                const SizedBox(height: 14),

                // role chips (visual only)
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
                        _role == UserRole.caregiver,
                        () => setState(() => _role = UserRole.caregiver),
                      ),
                      const SizedBox(width: 8),
                      _roleChip(
                        'Elderly',
                        _role == UserRole.elderly,
                        () => setState(() => _role = UserRole.elderly),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _user,
                        style: inputTextStyle,
                        decoration: InputDecoration(
                          labelText: 'Username or email',
                          labelStyle: labelStyle,
                          prefixIcon: const Icon(Icons.person_outline),
                          contentPadding: fieldContentPadding,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                          contentPadding: fieldContentPadding,
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),

                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: buttonStyle,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator())
                      : const Text('Next'),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don’t have an account?",
                        style: TextStyle(color: Colors.grey.shade700)),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      ),
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
