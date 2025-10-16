import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ElderlySignUpPage extends StatefulWidget {
  const ElderlySignUpPage({super.key});

  @override
  State<ElderlySignUpPage> createState() => _ElderlySignUpPageState();
}

class _ElderlySignUpPageState extends State<ElderlySignUpPage> {
  int _step = 0;
  bool _loading = false;
  bool _ob = true;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();

  String _gender = 'Male';

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _nextStep() => setState(() => _step++);
  void _prevStep() => setState(() => _step--);

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _createAccount() async {
    if (_email.text.isEmpty || !_email.text.contains('@')) {
      _show('Enter a valid email');
      return;
    }
    if (_pass.text.length < 6) {
      _show('Password must be at least 6 characters');
      return;
    }
    if (_first.text.isEmpty || _last.text.isEmpty) {
      _show('Enter your first and last name');
      return;
    }
    if (!RegExp(r'^05\d{8}$').hasMatch(_phone.text)) {
      _show('Enter a valid Saudi phone number (05XXXXXXXX)');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'role': 'elderly',
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'gender': _gender.toLowerCase(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _show('Account created ✅');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _show('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Elderly Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: switch (_step) {
            0 => _stepEmail(cs),
            1 => _stepNameGender(cs),
            2 => _stepPhone(cs),
            3 => _stepConfirm(cs),
            _ => const SizedBox(),
          },
        ),
      ),
    );
  }

  // 🟢 STEP 1 — Email & Password
  Widget _stepEmail(ColorScheme cs) => Column(
        key: const ValueKey(0),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 1 of 4 — Account Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pass,
            obscureText: _ob,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _ob = !_ob),
                icon: Icon(_ob ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextStep,
            child: const Text('Next'),
          ),
        ],
      );

  // 🟢 STEP 2 — Name & Gender
  Widget _stepNameGender(ColorScheme cs) => Column(
        key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 2 of 4 — Personal Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _first,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'First name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _last,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Last name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.wc_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'Male'),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _prevStep, child: const Text('Back'))),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      ElevatedButton(onPressed: _nextStep, child: const Text('Next'))),
            ],
          ),
        ],
      );

  // 🟢 STEP 3 — Phone
  Widget _stepPhone(ColorScheme cs) => Column(
        key: const ValueKey(2),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 3 of 4 — Contact Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '05XXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _prevStep, child: const Text('Back'))),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      ElevatedButton(onPressed: _nextStep, child: const Text('Next'))),
            ],
          ),
        ],
      );

  // 🟢 STEP 4 — Confirm & Create
  Widget _stepConfirm(ColorScheme cs) => Column(
        key: const ValueKey(3),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Step 4 of 4 — Confirm',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
            color: cs.surfaceVariant,
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '📧 Email: ${_email.text}\n'
                '👤 Name: ${_first.text} ${_last.text}\n'
                '🚻 Gender: $_gender\n'
                '📞 Phone: ${_phone.text}',
                style: const TextStyle(fontSize: 18, height: 1.6),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _prevStep, child: const Text('Back'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _createAccount,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ],
      );
}
