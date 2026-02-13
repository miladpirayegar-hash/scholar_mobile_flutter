import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/user_prefs_provider.dart';
import '../theme/app_theme.dart';

class AuthModal extends ConsumerStatefulWidget {
  const AuthModal({super.key});

  @override
  ConsumerState<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends ConsumerState<AuthModal> {
  bool _isSignup = true;
  bool _hasAccount = false;
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _needsVerification = false;
  bool _verificationSent = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAccountState();
  }

  Future<void> _loadAccountState() async {
    final hasAccount = ref.read(userPrefsProvider).hasAccount;
    if (!mounted) return;
    setState(() {
      _hasAccount = hasAccount;
      if (hasAccount) _isSignup = false;
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void _setError(String? message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        setState(() => _resendCooldown = 0);
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown -= 1);
    });
  }

  Future<void> _submit() async {
    final rawEmail = _email.text.trim();
    final rawPassword = _password.text.trim();
    if (rawEmail.isEmpty) {
      _setError('Email is required.');
      return;
    }
    if (!_isValidEmail(rawEmail)) {
      _setError('Enter a valid email address.');
      return;
    }
    if (rawPassword.isEmpty) {
      _setError('Password is required.');
      return;
    }
    if (rawPassword.length < 6) {
      _setError('Password must be at least 6 characters.');
      return;
    }
    if (_isSignup && _name.text.trim().isEmpty) {
      _setError('Full name is required.');
      return;
    }
    if (_isSignup) {
      final confirm = _confirmPassword.text.trim();
      if (confirm.isEmpty) {
        _setError('Please confirm your password.');
        return;
      }
      if (confirm != rawPassword) {
        _setError('Passwords do not match.');
        return;
      }
    }
    _setError(null);
    setState(() => _isSubmitting = true);
    try {
      if (_isSignup) {
        await ref.read(authProvider.notifier).signUpWithEmail(
              name: _name.text.trim(),
              email: rawEmail,
              password: rawPassword,
            );
        if (!mounted) return;
        setState(() {
          _needsVerification = true;
          _verificationSent = true;
        });
        _startCooldown();
        await ref
            .read(userPrefsProvider.notifier)
            .setNeedsOutlineUpload(true);
        return;
      } else {
        await ref.read(authProvider.notifier).signInWithEmail(
              email: rawEmail,
              password: rawPassword,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      final message = mapAuthError(e);
      _setError(message);
      if (message.toLowerCase().contains('not verified')) {
        setState(() => _needsVerification = true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final rawEmail = _email.text.trim();
    if (rawEmail.isEmpty) {
      _setError('Enter your email to reset password.');
      return;
    }
    if (!_isValidEmail(rawEmail)) {
      _setError('Enter a valid email address.');
      return;
    }
    _setError(null);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authProvider.notifier)
          .sendPasswordReset(email: rawEmail);
      if (!mounted) return;
      _setError('Password reset email sent. Check your inbox.');
    } catch (e) {
      _setError(mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendVerification() async {
    final rawEmail = _email.text.trim();
    final rawPassword = _password.text.trim();
    if (rawEmail.isEmpty || rawPassword.isEmpty) {
      _setError('Enter your email and password to resend verification.');
      return;
    }
    if (!_isValidEmail(rawEmail)) {
      _setError('Enter a valid email address.');
      return;
    }
    _setError(null);
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authProvider.notifier).resendVerificationEmail(
            email: rawEmail,
            password: rawPassword,
          );
      if (!mounted) return;
      setState(() => _verificationSent = true);
      _startCooldown();
      _setError('Verification email sent. Check your inbox.');
    } catch (e) {
      _setError(mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    _TabPill(
                      label: 'SIGN UP',
                      active: _isSignup,
                      onTap: () => setState(() => _isSignup = true),
                    ),
                    _TabPill(
                      label: 'LOG IN',
                      active: !_isSignup,
                      onTap: () => setState(() => _isSignup = false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isSignup) ...[
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'FULL NAME',
            ),
            onChanged: (_) => _setError(null),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          decoration: const InputDecoration(
            labelText: 'ACADEMIC EMAIL',
          ),
          onChanged: (_) => _setError(null),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'PASSWORD',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
          onChanged: (_) => _setError(null),
        ),
        if (_isSignup) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassword,
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              labelText: 'CONFIRM PASSWORD',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _showConfirm = !_showConfirm),
                icon: Icon(
                  _showConfirm ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            onChanged: (_) => _setError(null),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD5D5)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_needsVerification) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB8D9FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check your email to verify your account.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You must verify your email before logging in.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.subtext,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (_isSubmitting || _resendCooldown > 0)
                        ? null
                        : _resendVerification,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : (_verificationSent ? 'Resend email' : 'Send again'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _isSubmitting
                  ? 'Please wait...'
                  : (_isSignup ? 'Create Account' : 'Log In'),
            ),
          ),
        ),
        if (!_isSignup) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSubmitting ? null : _forgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
        ],
        if (_hasAccount && _isSignup) ...[
          const SizedBox(height: 8),
          const Text(
            'You can create a new account or log in to an existing one.',
            style: TextStyle(fontSize: 12, color: AppColors.subtext),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(authProvider.notifier).signInWithGoogle();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    } catch (e) {
                      _setError(mapAuthError(e));
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Continue with Google',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: active ? AppColors.primary : AppColors.subtext,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
