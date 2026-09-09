import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/my_widgets/auth_shell.dart';
import '../theme/app_colors.dart';

/// Reset Password — mirrors the web /reset-password, wired to
/// `/auth/reset-password`. The code is the token from the emailed reset link.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) {
      _toast('Enter the reset code from your email');
      return;
    }
    if (_password.text != _confirm.text) {
      _toast("Passwords do not match");
      return;
    }
    if (_password.text.length < 8) {
      _toast('Password must be at least 8 characters');
      return;
    }
    setState(() => _loading = true);
    final ok = await AuthController.instance.resetPassword(_code.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      setState(() => _done = true);
    } else {
      _toast(AuthController.instance.error ?? 'That reset link is invalid or expired');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: AuthCard(
        title: 'Set a New Password',
        subtitle: 'Enter the reset code from your email, then choose a new strong password.',
        child: _done
            ? Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 60),
                  const SizedBox(height: 12),
                  const Text(
                    'Password Reset!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your password was reset. You can now log in with your new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: AuthPrimaryButton(
                      label: 'GO TO LOGIN',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(controller: _code, hint: 'Reset Code', keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  PasswordField(controller: _password, hint: 'New Password'),
                  const SizedBox(height: 14),
                  PasswordField(controller: _confirm, hint: 'Confirm New Password'),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: AuthPrimaryButton(label: 'RESET PASSWORD', onTap: _submit, loading: _loading),
                  ),
                ],
              ),
      ),
    );
  }
}