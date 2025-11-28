import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elderly_Screens/screens/elderly_home.dart';

class ElderlySignUpPage extends StatefulWidget {
  const ElderlySignUpPage({super.key});

  @override
  State<ElderlySignUpPage> createState() => _ElderlySignUpPageState();
}

class _ElderlySignUpPageState extends State<ElderlySignUpPage> {
  int _step = 0;
  bool _loading = false;
  bool _ob = true;
  bool _obConfirm = true;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();

  String _gender = 'Male';

  final _form0 = GlobalKey<FormState>(); // Email
  final _form1 = GlobalKey<FormState>(); // Name/Gender
  final _form2 = GlobalKey<FormState>(); // Phone
  final _form3 = GlobalKey<FormState>(); // Password

  String? _emailError;
  String? _phoneError;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _prettyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email.';
      case 'weak-password':
        return 'Weak password.';
      case 'network-request-failed':
        return 'Network error. Check connection.';
      default:
        return e.message ?? e.code;
    }
  }

  void _showInlineTopError(BuildContext context, String msg) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ================= async checks =================

  Future<bool> _emailIsUsed(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return methods.isNotEmpty || snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _phoneIsUsed(String phone) async {
    try {
      final snap = await _db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _validateAllAndJumpToError() {
    final mail = _email.text.trim();
    final fname = _first.text.trim();
    final lname = _last.text.trim();
    final phone = _phone.text.trim();
    final pass = _pass.text;
    final pass2 = _passConfirm.text;

    final emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(mail);
    if (!emailValid || _emailError != null) {
      setState(() => _step = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form0.currentState?.validate();
      });
      return false;
    }

    if (fname.isEmpty || lname.isEmpty) {
      setState(() => _step = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form1.currentState?.validate();
      });
      return false;
    }

    final phoneValid = RegExp(r'^05\d{8}$').hasMatch(phone);
    if (!phoneValid || _phoneError != null) {
      setState(() => _step = 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form2.currentState?.validate();
      });
      return false;
    }

    if (pass.length < 6 || pass2 != pass) {
      setState(() => _step = 3);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form3.currentState?.validate();
      });
      return false;
    }

    return true;
  }

  // =============== steps navigation (مع انتظار الفحص) ===============

  Future<void> _nextStep() async {
    FocusScope.of(context).unfocus();
    bool ok = false;

    switch (_step) {
      case 0:
        ok = _form0.currentState?.validate() ?? false;
        if (!ok) break;

        setState(() => _emailError = null);

        final email = _email.text.trim();
        if (email.isNotEmpty) {
          final used = await _emailIsUsed(email);
          if (used) {
            setState(() {
              _emailError = 'Email already in use';
            });
            _form0.currentState?.validate();
            ok = false;
          }
        }
        break;

      case 1:
        ok = _form1.currentState?.validate() ?? false;
        break;

      case 2:
        ok = _form2.currentState?.validate() ?? false;
        if (!ok) break;

        setState(() => _phoneError = null);

        final phone = _phone.text.trim();
        if (phone.isNotEmpty) {
          final used = await _phoneIsUsed(phone);
          if (used) {
            setState(() {
              _phoneError = 'Phone number already used';
            });
            _form2.currentState?.validate();
            ok = false;
          }
        }
        break;

      case 3:
        ok = _form3.currentState?.validate() ?? false;
        break;

      default:
        ok = true;
    }

    if (ok) {
      setState(() => _step++);
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _createAccount() async {
    final email = _email.text.trim();
    final phone = _phone.text.trim();

    _emailError = null;
    _phoneError = null;

    if (email.isNotEmpty && await _emailIsUsed(email)) {
      setState(() {
        _emailError = 'Email already in use';
        _step = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form0.currentState?.validate();
      });
      return;
    }

    if (phone.isNotEmpty && await _phoneIsUsed(phone)) {
      setState(() {
        _phoneError = 'Phone number already used';
        _step = 2;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form2.currentState?.validate();
      });
      return;
    }

    if (!_validateAllAndJumpToError()) return;

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _pass.text.trim(),
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'role': 'elderly',
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'gender': _gender.toLowerCase(),
        'phone': phone,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'caregiverIds': <String>[],
        'pairingCode': null,
        'pairingCodeCreatedAt': null,
      });

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ElderlyHomePage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use' && mounted) {
        setState(() {
          _emailError = 'Email already in use';
          _step = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _form0.currentState?.validate();
        });
        return;
      }
      _showInlineTopError(context, _prettyAuthError(e));
    } catch (e) {
      _showInlineTopError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );

    final baseTheme = Theme.of(context);
    final bigErrorTheme = baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        errorStyle: const TextStyle(
          fontSize: 18,
          color: Colors.red,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Elderly Sign Up')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Theme(
              data: bigErrorTheme,
              child: Card(
                elevation: 6,
                surfaceTintColor: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey(_step),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const SizedBox(height: 16),
                        Expanded(
                          child: switch (_step) {
                            0 => _stepEmail(cs),
                            1 => _stepNameGender(cs),
                            2 => _stepPhone(cs),
                            3 => _stepPassword(cs),
                            4 => _stepConfirm(cs),
                            _ => const SizedBox(),
                          },
                        ),
                        const SizedBox(height: 10),
                        _footerButtons(buttonStyle),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final stepsText = 'Step ${_step + 1} of 5';
    return Row(
      children: [
        const Icon(Icons.assignment_turned_in_outlined),
        const SizedBox(width: 8),
        Text(
          stepsText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Row(
          children: List.generate(5, (i) {
            final active = i <= _step;
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Colors.blueGrey : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _footerButtons(ButtonStyle buttonStyle) {
    if (_step < 4) {
      return Row(
        children: [
          if (_step > 0)
            Expanded(
              child: FilledButton(
                onPressed: _prevStep,
                style: buttonStyle.copyWith(
                  backgroundColor:
                      WidgetStateProperty.all<Color>(Colors.white),
                  foregroundColor:
                      WidgetStateProperty.all<Color>(Colors.black87),
                  side: WidgetStateProperty.all<BorderSide>(
                    const BorderSide(color: Colors.black54),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _nextStep,
              style: buttonStyle,
              child: const Text('Next'),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _prevStep,
              style: buttonStyle.copyWith(
                backgroundColor:
                    WidgetStateProperty.all<Color>(Colors.white),
                foregroundColor:
                    WidgetStateProperty.all<Color>(Colors.black87),
                side: WidgetStateProperty.all<BorderSide>(
                  const BorderSide(color: Colors.black54),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _loading ? null : _createAccount,
              style: buttonStyle,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(),
                    )
                  : const Text(
                      'Sign up',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      );
    }
  }

  // ====== step 0: Email ======
  Widget _stepEmail(ColorScheme cs) => Form(
        key: _form0,
        child: ListView(
          children: [
            const Text(
              'Account Email',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Email',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 20),
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailError,
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Required';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) {
                  return 'Enter a valid email';
                }
                return _emailError;
              },
            ),
          ],
        ),
      );

  // ====== step 1: Name & Gender ======
  Widget _stepNameGender(ColorScheme cs) => Form(
        key: _form1,
        child: ListView(
          children: [
            const Text(
              'Personal Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'First name',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _first,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            const Text(
              'Last name',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _last,
              style: const TextStyle(fontSize: 20),
              decoration:
                  const InputDecoration(prefixIcon: Icon(Icons.person)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            const Text(
              'Gender',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.wc_outlined),
              ),
              onChanged: (v) => setState(() => _gender = v ?? 'Male'),
            ),
          ],
        ),
      );

  // ====== step 2: Phone ======
  Widget _stepPhone(ColorScheme cs) => Form(
        key: _form2,
        child: ListView(
          children: [
            const Text(
              'Contact Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Phone number',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (_) {
                if (_phoneError != null) {
                  setState(() => _phoneError = null);
                }
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_outlined),
                errorMaxLines: 2,
                errorText: _phoneError,
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Required';
                if (!RegExp(r'^05\d{8}$').hasMatch(s)) {
                  return 'Phone number must start with 05';
                }
                return _phoneError;
              },
            ),
          ],
        ),
      );

  // ====== step 3: Password ======
  Widget _stepPassword(ColorScheme cs) => Form(
        key: _form3,
        child: ListView(
          children: [
            const Text(
              'Account Security',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Password',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _pass,
              obscureText: _ob,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _ob = !_ob),
                  icon:
                      Icon(_ob ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 14),
            const Text(
              'Confirm password',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passConfirm,
              obscureText: _obConfirm,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obConfirm = !_obConfirm),
                  icon: Icon(
                      _obConfirm ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _pass.text) return 'Passwords do not match';
                return null;
              },
            ),
          ],
        ),
      );

  // ====== step 4: Confirm ======
  Widget _stepConfirm(ColorScheme cs) => ListView(
        children: [
          const Text(
            'Confirm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            color: cs.surfaceVariant,
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
        ],
      );
}
