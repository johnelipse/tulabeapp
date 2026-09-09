import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/my_widgets/auth_shell.dart';
import 'package:tulabe/screens/register_screen.dart';
import 'package:tulabe/screens/forgot_password_screen.dart';

/// Log In — mirrors the web /login, wired to the Go `/auth/login` endpoint.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _toast('Please enter your email and password');
      return;
    }
    setState(() => _loading = true);
    final ok = await AuthController.instance.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // Match the web: landing back where the login flow was started.
      _toast('Welcome back!');
      Navigator.pop(context);
    } else {
      _toast(AuthController.instance.error ?? 'Login failed');
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
        title: 'Log In',
        subtitle: 'Type in Your Email and Password',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(controller: _email, hint: 'Your Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            const _OrDivider(),
            const SizedBox(height: 14),
            PasswordField(controller: _password, hint: 'Enter password'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    ),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF262A30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'FORGOT PASSWORD?',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  height: 48,
                  child: AuthPrimaryButton(label: 'LOG IN', onTap: _login, loading: _loading),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text("Don't have an account?", style: TextStyle(color: Color(0xFF8E95A5), fontSize: 13)),
            ),
            const SizedBox(height: 10),
            AuthSecondaryButton(
              leading: const Icon(Icons.person_add_alt, color: Colors.white70, size: 18),
              label: 'Create Account',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Or', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.white12)),
      ],
    );
  }
}