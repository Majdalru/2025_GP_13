import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import '../providers/locale_provider.dart';
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
  final _db = FirebaseFirestore.instance;

  UserRole _role = UserRole.caregiver;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _ob = true, _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _showLanguagePicker(LocaleProvider localeProvider) async {
    final currentLang = localeProvider.currentLanguageCode;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Choose Language',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3A52),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر لغة التطبيق',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 22),
                _buildLanguageOption(
                  title: 'العربية',
                  subtitle: 'Arabic',
                  isSelected: currentLang == 'ar',
                  onTap: () {
                    localeProvider.setArabic();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 14),
                _buildLanguageOption(
                  title: 'English',
                  subtitle: 'الإنجليزية',
                  isSelected: currentLang == 'en',
                  onTap: () {
                    localeProvider.setEnglish();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1B3A52).withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B3A52)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xFF1B3A52)
                  : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B3A52),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCenteredDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w800),
          child: Text(title),
        ),
        content: DefaultTextStyle.merge(
          style: const TextStyle(height: 1.3),
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  String _prettyAuthError(FirebaseAuthException e) {
    if (!mounted) return '';
    final loc = AppLocalizations.of(context)!;
    switch (e.code) {
      case 'invalid-email':
        return loc.invalidEmailAuth;
      case 'too-many-requests':
        return loc.tooManyRequestsAuth;
      case 'user-disabled':
        return loc.accountDisabledAuth;
      case 'network-request-failed':
        return loc.networkErrorAuth;
      default:
        return loc.signInGenericError;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final password = _pass.text.trim();

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists || snap.data() == null) {
        await _auth.signOut();
        await _showCenteredDialog(
          AppLocalizations.of(context)!.signInFailed,
          AppLocalizations.of(context)!.signInGenericError,
        );
        return;
      }

      final roleStr = (snap.data()!['role'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final actualRole = roleStr == 'elderly'
          ? UserRole.elderly
          : UserRole.caregiver;

      if (actualRole != _role) {
        await _auth.signOut();
        await _showCenteredDialog(
          AppLocalizations.of(context)!.signInFailed,
          AppLocalizations.of(context)!.signInGenericError,
        );
        return;
      }

      if (!mounted) return;
      if (actualRole == UserRole.elderly) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ElderlyHomePage()),
        );
      } else {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await _showCenteredDialog(
        AppLocalizations.of(context)!.signInFailed,
        _prettyAuthError(e),
      );
    } catch (_) {
      if (!mounted) return;
      await _showCenteredDialog(
        AppLocalizations.of(context)!.signInFailed,
        AppLocalizations.of(context)!.signInGenericError,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final w = size.width;

    const maxContentWidth = 480.0;
    final logoH = (w * 0.22).clamp(80, 140);

    final isElderly = _role == UserRole.elderly;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: isElderly ? 34 : 24,
    );
    final inputTextStyle = TextStyle(fontSize: isElderly ? 20 : 15);
    final labelTextStyle = TextStyle(
      fontSize: isElderly ? 28 : 14,
      fontWeight: FontWeight.w600,
    );
    final helperErrStyle = TextStyle(fontSize: isElderly ? 16 : 12);
    final fieldPadding = EdgeInsets.symmetric(
      vertical: isElderly ? 22 : 16,
      horizontal: 14,
    );
    final linkTextStyle = TextStyle(
      fontSize: isElderly ? 18 : 14,
      color: cs.primary,
      fontWeight: FontWeight.w600,
    );

    final buttonStyle = FilledButton.styleFrom(
      minimumSize: Size.fromHeight(isElderly ? 60 : 56),
      textStyle: TextStyle(
        fontSize: isElderly ? 20 : 16,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    InputDecoration _dec({required IconData icon}) => InputDecoration(
      prefixIcon: Icon(icon),
      contentPadding: fieldPadding,
      labelText: null,
      hintText: null,
      errorStyle: helperErrStyle,
      errorMaxLines: 2,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Language',
            onPressed: () => _showLanguagePicker(localeProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.asset(
                      'assets/khalil_logo.png',
                      height: logoH.toDouble(),
                      width: logoH.toDouble(),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(loc.login, style: titleStyle)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _roleChip(
                        loc.caregiver,
                        _role == UserRole.caregiver,
                        () => setState(() => _role = UserRole.caregiver),
                      ),
                      const SizedBox(width: 8),
                      _roleChip(
                        loc.elderly,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(loc.email, style: labelTextStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: inputTextStyle,
                        decoration: _dec(icon: Icons.email_outlined),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return loc.requiredField;
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) {
                            return loc.invalidEmail;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(loc.password, style: labelTextStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pass,
                        obscureText: _ob,
                        style: inputTextStyle,
                        decoration: _dec(icon: Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _ob = !_ob),
                            icon: Icon(
                              _ob ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? loc.shortPassword
                            : null,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordPage(
                                isElderly: _role == UserRole.elderly,
                              ),
                            ),
                          ),
                          child: Text(loc.forgotPassword, style: linkTextStyle),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: buttonStyle,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(loc.next),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loc.dontHaveAccount,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: isElderly ? 18 : 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_role == UserRole.elderly) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ElderlySignUpPage(),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignUpPage(),
                            ),
                          );
                        }
                      },
                      child: Text(loc.signUp, style: linkTextStyle),
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