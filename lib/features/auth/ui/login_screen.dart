import 'package:clubera/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repo.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authRepo = AuthRepo();
  bool _loading = false;
  bool _obscure = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await _authRepo.isBiometricAvailable();
    final enabled = await _authRepo.isBiometricEnabled();
    if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
  }

  Future<void> _loginWithBiometric() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = await _authRepo.loginWithBiometric();
      if (user == null && mounted) setState(() => _error = 'Η αναγνώριση ακυρώθηκε. Δοκίμασε ξανά.');
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('no_credentials')) {
          setState(() {
            _biometricEnabled = false;
            _error = AppLocalizations.of(context).au_err_biometric_relogin;
          });
        } else {
          setState(() => _error = AppLocalizations.of(context).au_err_biometric_failed);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppProvider>().login(_emailCtrl.text, _passCtrl.text);
      // Offer to enable biometric after successful password login
      if (_biometricAvailable && !_biometricEnabled && mounted) {
        _offerBiometric();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _offerBiometric() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(AppLocalizations.of(context).au_biometric_title, style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Θέλεις να συνδέεσαι με δακτυλικό αποτύπωμα την επόμενη φορά;',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).au_no)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authRepo.setBiometricEnabled(
                enabled: true,
                email: _emailCtrl.text,
                password: _passCtrl.text,
              );
              if (mounted) setState(() => _biometricEnabled = true);
            },
            child: Text(AppLocalizations.of(context).au_yes),
          ),
        ],
      ),
    );
  }

  static String _friendlyAuthError(BuildContext context, Object e) {
    final l = AppLocalizations.of(context);
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          return l.au_err_invalid_credentials;
        case 'wrong-password': return l.au_err_wrong_password;
        case 'invalid-email': return l.au_err_invalid_email;
        case 'user-disabled': return l.au_err_disabled;
        case 'network-request-failed': return l.au_err_no_internet;
        case 'too-many-requests': return l.au_err_too_many;
        default: return e.message ?? l.au_err_sign_in_failed;
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    const SizedBox(height: 20),
                    _buildLogo(),
                    const SizedBox(height: 24),
                    Text(AppLocalizations.of(context).au_welcome_back, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(AppLocalizations.of(context).au_sign_in_subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).au_email,
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? AppLocalizations.of(context).au_err_email : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).au_password,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? AppLocalizations.of(context).au_err_password : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPassword,
                    child: Text(AppLocalizations.of(context).au_forgot, style: TextStyle(color: AppTheme.primaryLight)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13))),
                        if (_error == AppLocalizations.of(context).au_err_biometric_failed && _biometricAvailable)
                          TextButton(
                            onPressed: _loading ? null : _loginWithBiometric,
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            child: Text(AppLocalizations.of(context).au_retry, style: TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(context).au_sign_in),
                  ),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _loginWithBiometric,
                      icon: const Icon(Icons.fingerprint, size: 22),
                      label: Text(_biometricEnabled ? AppLocalizations.of(context).au_biometric_login : AppLocalizations.of(context).au_biometric_enable),
                    ),
                  ),
                ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppLocalizations.of(context).au_no_account, style: TextStyle(color: AppTheme.textSecondary)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: Text(AppLocalizations.of(context).au_sign_up, style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildLogo() => Center(
    child: Image.asset('assets/images/logo.jpeg', height: 110),
  );

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(AppLocalizations.of(context).au_reset_title, style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: AppLocalizations.of(context).au_email, labelStyle: TextStyle(color: AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).home_cancel)),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              try {
                await context.read<AppProvider>().resetPassword(ctrl.text);
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).au_reset_sent)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text(AppLocalizations.of(context).au_send),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }
}
