import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import 'elderly_sign_up_page.dart';
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

  // Dialog عام وآمن
  Future<void> _showCenteredDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  String _prettyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':  return 'Invalid email address.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      case 'user-disabled':  return 'This account has been disabled.';
      case 'network-request-failed': return 'Network error. Check your internet connection.';
      default: return 'Unable to sign in. Please check your email, password, or account type.';
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final email    = _email.text.trim();
      final password = _pass.text.trim();

      // 1) Auth
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      // 2) Fetch profile
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists || snap.data() == null) {
        await _auth.signOut();
        await _showCenteredDialog(
          'Sign-in failed',
          'Unable to sign in. Please check your email, password, or account type.',
        );
        return;
      }

      // 3) Role gating
      final roleStr = (snap.data()!['role'] ?? '').toString().toLowerCase().trim();
      final actualRole = roleStr == 'elderly' ? UserRole.elderly : UserRole.caregiver;

      if (actualRole != _role) {
        await _auth.signOut();
        await _showCenteredDialog(
          'Sign-in failed',
          'Unable to sign in. Please check your email, password, or account type.',
        );
        return;
      }

      // 4) Navigate
      if (!mounted) return;
      if (actualRole == UserRole.elderly) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ElderlyHomePage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await _showCenteredDialog('Sign-in failed', _prettyAuthError(e));
    } catch (_) {
      if (!mounted) return;
      await _showCenteredDialog(
        'Sign-in failed',
        'Unable to sign in. Please check your email, password, or account type.',
      );
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

    final isElderly      = _role == UserRole.elderly;

    // أحجام Elderly أكبر للوضوح (بدون تكبير إضافي للحقول نفسها)
    final titleStyle     = TextStyle(fontWeight: FontWeight.w900, fontSize: isElderly ? 34 : 24);
    final inputTextStyle = TextStyle(fontSize: isElderly ? 20 : 15);
    final labelTextStyle = TextStyle(fontSize: isElderly ? 28 : 14, fontWeight: FontWeight.w600);
    final helperErrStyle = TextStyle(fontSize: isElderly ? 16 : 12); // ← هنا التكبير للـ Elderly فقط
    final fieldPadding   = EdgeInsets.symmetric(vertical: isElderly ? 22 : 16, horizontal: 14);
    final linkTextStyle  = TextStyle(fontSize: isElderly ? 18 : 14, color: cs.primary, fontWeight: FontWeight.w600);

    final buttonStyle    = FilledButton.styleFrom(
      minimumSize: Size.fromHeight(isElderly ? 60 : 56),
      textStyle: TextStyle(fontSize: isElderly ? 20 : 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    // نحقن errorStyle في الـ decoration مباشرة
    InputDecoration _dec({required IconData icon}) => InputDecoration(
      prefixIcon: Icon(icon),
      contentPadding: fieldPadding,
      labelText: null,
      hintText: null,
      errorStyle: helperErrStyle, // 👈 هذا اللي يكبّر نص الخطأ عند Elderly
      errorMaxLines: 2,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // Logo
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
                const SizedBox(height: 8),

                Center(child: Text('Log in', style: titleStyle)),
                const SizedBox(height: 14),

                // Role chips
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

                // ===== Form =====
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Email', style: labelTextStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: inputTextStyle,
                        decoration: _dec(icon: Icons.email_outlined),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) return 'Enter a valid email';
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      Text('Password', style: labelTextStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pass,
                        obscureText: _ob,
                        style: inputTextStyle,
                        decoration: _dec(icon: Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _ob = !_ob),
                            icon: Icon(_ob ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                          ),
                          child: Text('Forgot password?', style: linkTextStyle),
                        ),
                      ),
                    ],
                  ),
                ),

                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: buttonStyle,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Next'),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account?",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: isElderly ? 18 : 14),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_role == UserRole.elderly) {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ElderlySignUpPage()));
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpPage()));
                        }
                      },
                      child: Text('Sign up', style: linkTextStyle),
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
