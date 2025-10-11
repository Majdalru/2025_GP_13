import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _ob1 = true, _ob2 = true;

  @override
  void dispose() {
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset successfully')),
    );
    Navigator.pop(context); // يرجع للـ Log in
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final w = size.width;

    // حد أقصى لعرض المحتوى + مقاسات مرنة مماثلة للصفحة السابقة
    const maxContentWidth = 480.0;
    final logoH = (w * 0.22).clamp(80, 140); // 80..140

    // حشوات ثابتة مريحة
    const fieldContentPadding = EdgeInsets.symmetric(vertical: 18, horizontal: 14);
    final inputTextStyle = Theme.of(context).textTheme.bodyLarge;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);


    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center( // لتطبيق الحد الأقصى للعرض
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), // تم تقليل الحشوة العلوية لأن AppBar موجود
            children: [
              const SizedBox(height: 16), // مسافة بعد الـ AppBar
              
              // LOGO بنفس الشكل السابق
              Container(
                height: logoH.toDouble(),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/khalil_logo.png', // تأكد من أن المسار صحيح
                  height: (logoH * 0.72).toDouble(),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              Text('Create a new password',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _newPass,
                      obscureText: _ob1,
                      style: inputTextStyle,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        labelStyle: labelStyle,
                        prefixIcon: const Icon(Icons.lock_reset),
                        contentPadding: fieldContentPadding,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _ob1 = !_ob1),
                          icon: Icon(_ob1 ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _ob2,
                      style: inputTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        labelStyle: labelStyle,
                        prefixIcon: const Icon(Icons.lock_outline),
                        contentPadding: fieldContentPadding,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _ob2 = !_ob2),
                          icon: Icon(_ob2 ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) =>
                          (v != _newPass.text) ? 'Passwords do not match' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56), // تم توحيد ارتفاع الزر
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Reset password'), // تم تغيير نص الزر ليكون أوضح
              ),
            ],
          ),
        ),
      ),
    );
  }
}