import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/my_widgets/auth_shell.dart';
import 'package:tulabe/screens/reset_password_screen.dart';
import '../theme/app_colors.dart';

/// Forgot Password — mirrors the web /forgot-password, wired to
/// `/auth/forgot-password`.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() => _loading = true);
    final ok = await AuthController.instance.forgotPassword(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // The API always returns the generic "if that email exists" message.
      setState(() => _sent = true);
    } else {
      _toast(AuthController.instance.error ?? 'Something went wrong');
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
        title: 'Forgot Password',
        subtitle: 'No worries, stuff happens. Enter your email and we will send you a reset link.',
        child: _sent
            ? Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 60),
                  const SizedBox(height: 12),
                  const Text(
                    'Check Your Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a password reset link to ${_email.text.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: AuthPrimaryButton(
                      label: 'BACK TO LOGIN',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(controller: _email, hint: 'Your Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: AuthPrimaryButton(label: 'SEND RESET LINK', onTap: _send, loading: _loading),
                  ),
                  const SizedBox(height: 46),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
                    child: const Center(
                      child: Text('Have a reset code? Enter it —>', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}