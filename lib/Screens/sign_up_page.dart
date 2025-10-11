import 'package:flutter/material.dart';
import 'home_shell.dart';

enum SignUpRole { caregiver, elderly }

// محاكاة أسماء مستخدمين محجوزة (بديل مؤقت للباك إند)
final Set<String> _takenUsernames = {'user1', 'ahmed', 'care123'};

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  SignUpRole _role = SignUpRole.caregiver;

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == SignUpRole.elderly) {
      // لا انتقال للألدِرلي الآن
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elderly app coming soon')),
      );
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isElderly = _role == SignUpRole.elderly;

    // أحجام متكيّفة للألدِرلي
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

          // اختيار الدور
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _roleChip('Caregiver', _role == SignUpRole.caregiver,
                    () => setState(() => _role = SignUpRole.caregiver)),
                const SizedBox(width: 8),
                _roleChip('Elderly', _role == SignUpRole.elderly,
                    () => setState(() => _role = SignUpRole.elderly)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // Username (unique)
                TextFormField(
                  controller: _username,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Username (unique)',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final u = v.trim().toLowerCase();
                    if (_takenUsernames.contains(u)) return 'Username is taken';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // First / Last
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

                // Gender (Male/Female فقط)
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

                // Phone
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 8) ? 'Enter a valid phone' : null,
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: inputTextStyle,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: labelStyle,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),

                // Password
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

          FilledButton(
            onPressed: _loading ? null : () {
              // محاكاة حجز اسم المستخدم محليًا
              final u = _username.text.trim().toLowerCase();
              if (u.isNotEmpty && !_takenUsernames.contains(u)) {
                _takenUsernames.add(u);
              }
              _submit();
            },
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator())
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
