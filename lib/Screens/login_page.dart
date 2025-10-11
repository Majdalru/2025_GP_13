import 'package:flutter/material.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import 'home_shell.dart';

enum UserRole { caregiver, elderly }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  UserRole _role = UserRole.caregiver;

  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _ob = true, _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == UserRole.elderly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elderly app coming soon')),
      );
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final w = size.width;

    // حد أقصى لعرض المحتوى + مقاسات مرنة
    const maxContentWidth = 480.0;
    final logoH = (w * 0.22).clamp(80, 140); // 80..140
    final isElderly = _role == UserRole.elderly;

    // أحجام الخطوط المتكيفة (أكبر للألدِرلي)
    final titleStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: isElderly ? 30 : 24,
    );
    final inputTextStyle = TextStyle(fontSize: isElderly ? 18 : 15);
    final labelStyle = TextStyle(
      fontSize: isElderly ? 16 : 13,
      fontWeight: FontWeight.w600,
    );

    // حشوات ثابتة مريحة
    const fieldContentPadding = EdgeInsets.symmetric(vertical: 18, horizontal: 14);
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
                // LOGO (معدّل: عرض الشعار مباشرة)
Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 10), // مسافة محيطة
    child: Image.asset(
      'assets/khalil_logo.png',
      height: logoH.toDouble(), // اجعل الشعار يملأ الارتفاع
      fit: BoxFit.contain,
    ),
  ),
),
                const SizedBox(height: 20),

                Text('Log in', style: titleStyle),
                const SizedBox(height: 14),

                // اختيار الدور
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
                  onPressed: _loading ? null : _submit,
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
