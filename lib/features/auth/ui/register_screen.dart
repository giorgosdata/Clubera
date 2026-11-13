import 'package:clubera/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppProvider>().register(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        name: _nameCtrl.text,
        role: 'fan',
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).au_create_account),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).au_join, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(AppLocalizations.of(context).au_register_subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).au_full_name,
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context).au_err_name : null,
                ),
                const SizedBox(height: 16),
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
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(context).au_create_account),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _friendlyAuthError(BuildContext context, Object e) {
    final l = AppLocalizations.of(context);
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use': return l.au_err_email_in_use;
        case 'weak-password': return l.au_err_weak_password;
        case 'invalid-email': return l.au_err_invalid_email;
        case 'network-request-failed': return l.au_err_no_internet;
        case 'too-many-requests': return l.au_err_too_many;
        default: return e.message ?? l.au_err_register_failed;
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }

}
