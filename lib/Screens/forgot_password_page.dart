import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class ForgotPasswordPage extends StatefulWidget {
  final bool isElderly; // نحدد هل المستخدم ألدرلي

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

  /// Popup Dialog
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
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _email.text.trim(),
      );

      await _showCenteredDialog(
        AppLocalizations.of(context)!.emailSent,
        AppLocalizations.of(context)!.passwordResetLinkSent,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      await _showCenteredDialog(
        AppLocalizations.of(context)!.error,
        e.message ?? AppLocalizations.of(context)!.somethingWentWrong,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isElderly = widget.isElderly;

    final titleStyle = TextStyle(
      fontSize: isElderly ? 26 : 22,
      fontWeight: FontWeight.bold,
    );

    final textStyle = TextStyle(fontSize: isElderly ? 20 : 14);

    final buttonTextStyle = TextStyle(
      fontSize: isElderly ? 20 : 16,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true, // مهم جداً لمشكلة الكيبورد
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.resetPassword)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/khalil_logo.png',
                  height: isElderly ? 110 : 90, // صغّرناه لأجل الكيبورد
                  filterQuality: FilterQuality.high,
                ),
              ),

              SizedBox(height: isElderly ? 18 : 24),

              Text(
                AppLocalizations.of(context)!.willSendPasswordResetLink,
                style: titleStyle,
              ),

              const SizedBox(height: 14),

              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _email,
                  style: textStyle,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.pleaseEnterYourEmail;
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                      return AppLocalizations.of(context)!.invalidEmailAddress;
                    }
                    return null;
                  },
                ),
              ),

              SizedBox(height: isElderly ? 30 : 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          AppLocalizations.of(context)!.sendResetLink,
                          style: buttonTextStyle,
                        ),
                ),
              ),

              const SizedBox(height: 40), // يمنع الالتصاق بالكيبورد
            ],
          ),
        ),
      ),
    );
  }
}
