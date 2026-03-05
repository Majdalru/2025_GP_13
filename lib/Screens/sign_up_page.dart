import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_shell.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();

  // مفاتيح لحقل الإيميل وحقل الرقم عشان نعمل validate لهم بس
  final GlobalKey<FormFieldState<String>> _emailFieldKey =
      GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _phoneFieldKey =
      GlobalKey<FormFieldState<String>>();

  late final FocusNode _emailFocusNode;
  late final FocusNode _phoneFocusNode;

  bool _ob = true;
  bool _obConfirm = true;
  bool _loading = false;
  String _gender = 'Male';

  String? _emailError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _runEmailDuplicateCheck();
      }
    });

    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) {
        _runPhoneDuplicateCheck();
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

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

  // ====== checks للإيميل والرقم (تستخدم مع الفوكس ومع Sign up) ======

  Future<bool> _runEmailDuplicateCheck() async {
    final email = _email.text.trim();
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    // لو فاضي أو صيغة غلط، نخلي validator العادي يطلع الخطأ
    if (email.isEmpty || !regex.hasMatch(email)) {
      setState(() => _emailError = null);
      _emailFieldKey.currentState?.validate(); // بس حقل الإيميل
      return false;
    }

    final used = await _emailIsUsed(email);
    setState(() {
      _emailError = used
          ? AppLocalizations.of(context)!.emailAlreadyInUse
          : null;
    });
    _emailFieldKey.currentState?.validate();
    return !used;
  }

  Future<bool> _runPhoneDuplicateCheck() async {
    final phone = _phone.text.trim();
    final regex = RegExp(r'^05\d{8}$');

    if (phone.isEmpty || !regex.hasMatch(phone)) {
      setState(() => _phoneError = null);
      _phoneFieldKey.currentState?.validate(); // بس حقل الرقم
      return false;
    }

    final used = await _phoneIsUsed(phone);
    setState(() {
      _phoneError = used
          ? AppLocalizations.of(context)!.phoneAlreadyUsed
          : null;
    });
    _phoneFieldKey.currentState?.validate();
    return !used;
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    // أولاً: فاليديشن عادي لكل الحقول (صيغة، فراغ، الخ)
    if (!_formKey.currentState!.validate()) return;

    // ثانياً: فحص تكرار الإيميل والرقم
    final okEmail = await _runEmailDuplicateCheck();
    final okPhone = await _runPhoneDuplicateCheck();

    if (!okEmail || !okPhone) {
      // لو واحد منهم مكرر ما نكمل
      return;
    }

    final email = _email.text.trim();
    final phone = _phone.text.trim();

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _pass.text.trim(),
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'role': 'caregiver',
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'email': email,
        'phone': phone,
        'gender': _gender.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'elderlyIds': <String>[],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account created ✅')));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (mounted) {
          setState(() {
            _emailError = AppLocalizations.of(context)!.emailAlreadyInUse;
          });
          _emailFieldKey.currentState?.validate();
        }
        return;
      }

      final msg = switch (e.code) {
        'invalid-email' => AppLocalizations.of(context)!.invalidEmailAddress,
        'weak-password' => AppLocalizations.of(context)!.weakPassword,
        _ => AppLocalizations.of(context)!.errorPrefix(e.code),
      };

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.caregiverSignUp),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          // لاحظي: ما فيه autovalidateMode هنا
          child: ListView(
            children: [
              // ===== Email =====
              Text(
                AppLocalizations.of(context)!.email,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: _emailFieldKey,
                controller: _email,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: _emailError,
                ),
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() => _emailError = null);
                    _emailFieldKey.currentState?.validate();
                  }
                },
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty)
                    return AppLocalizations.of(context)!.requiredField;
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) {
                    return AppLocalizations.of(context)!.enterValidEmail;
                  }
                  return _emailError;
                },
              ),

              // ===== First name =====
              gap,
              Text(
                AppLocalizations.of(context)!.firstName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _first,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              // ===== Last name =====
              gap,
              Text(
                AppLocalizations.of(context)!.lastName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _last,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              // ===== Gender =====
              gap,
              Text(
                AppLocalizations.of(context)!.gender,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _gender,
                items: [
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text(AppLocalizations.of(context)!.male),
                  ),
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text(AppLocalizations.of(context)!.female),
                  ),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
              ),

              // ===== Phone =====
              gap,
              Text(
                AppLocalizations.of(context)!.phoneNumber,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: _phoneFieldKey,
                controller: _phone,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _phoneError,
                ),
                onChanged: (_) {
                  if (_phoneError != null) {
                    setState(() => _phoneError = null);
                    _phoneFieldKey.currentState?.validate();
                  }
                },
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty)
                    return AppLocalizations.of(context)!.requiredField;
                  if (!RegExp(r'^05\d{8}$').hasMatch(s)) {
                    return AppLocalizations.of(context)!.enterValidSaudiNumber;
                  }
                  return _phoneError;
                },
              ),

              // ===== Password =====
              gap,
              Text(
                AppLocalizations.of(context)!.password,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pass,
                obscureText: _ob,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _ob = !_ob),
                    icon: Icon(_ob ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? AppLocalizations.of(context)!.min6Chars
                    : null,
              ),

              // ===== Confirm Password =====
              gap,
              Text(
                AppLocalizations.of(context)!.confirmPassword,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passConfirm,
                obscureText: _obConfirm,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obConfirm = !_obConfirm),
                    icon: Icon(
                      _obConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return AppLocalizations.of(context)!.requiredField;
                  if (v != _pass.text)
                    return AppLocalizations.of(context)!.passwordsDoNotMatch;
                  return null;
                },
              ),

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _createAccount,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(),
                      )
                    : Text(
                        AppLocalizations.of(context)!.signUp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
