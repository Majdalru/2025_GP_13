import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  final bool isElderly; // ✅ نحدد هل المستخدم ألدرلي

  const ForgotPasswordPage({super.key, required this.isElderly});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// ✅ نفس ستايل Dialog المستخدم في صفحة Login
  Future<void> _showCenteredDialog(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _email.text.trim());

      // ✅ Popup بدلاً من SnackBar
      await _showCenteredDialog(
        'Email sent',
        'A password reset link has been sent to your email.',
      );

      Navigator.pop(context); // يرجع لصفحة تسجيل الدخول
    } on FirebaseAuthException catch (e) {
      await _showCenteredDialog('Error', e.message ?? 'Something went wrong');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isElderly = widget.isElderly;
    final titleStyle = TextStyle(
      fontSize: isElderly ? 28 : 22,
      fontWeight: FontWeight.bold,
    );
    final textStyle = TextStyle(fontSize: isElderly ? 20 : 14);
    final buttonTextStyle =
        TextStyle(fontSize: isElderly ? 20 : 16, fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/khalil_logo.png',
                height: isElderly ? 140 : 100,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 24),

            Text("We'll send a password reset link to your email.", style: titleStyle),
            const SizedBox(height: 14),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _email,
                style: textStyle,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _resetPassword,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text('Send reset link', style: buttonTextStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
