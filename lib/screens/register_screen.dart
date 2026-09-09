import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/my_widgets/auth_shell.dart';
import 'package:tulabe/screens/login_screen.dart';

/// Create Account — mirrors the web /register, wired to `/auth/register`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      _toast('Please enter your first and last name');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _toast("Passwords do not match");
      return;
    }
    if (_password.text.length < 8) {
      _toast('Password must be at least 8 characters');
      return;
    }
    if (!_email.text.contains('@')) {
      _toast('Please enter a valid email');
      return;
    }
    setState(() => _loading = true);
    final ok = await AuthController.instance.register(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      password: _password.text,
      passwordConfirmation: _confirmPassword.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // Match the web: registration lands on the homepage.
      _toast('Account created — welcome to Tulabe!');
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _toast(AuthController.instance.error ?? 'Registration failed');
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
        title: 'Create Account',
        subtitle: 'Sign up to unlock full access to Tulabe',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AuthTextField(controller: _firstName, hint: 'First Name'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthTextField(controller: _lastName, hint: 'Last Name'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AuthTextField(controller: _email, hint: 'Your Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            PasswordField(controller: _password, hint: 'Choose a Password'),
            const SizedBox(height: 14),
            PasswordField(controller: _confirmPassword, hint: 'Confirm Password'),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: AuthPrimaryButton(
                label: 'SIGN UP',
                onTap: _register,
                loading: _loading,
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text('Already have an account?', style: TextStyle(color: Color(0xFF8E95A5), fontSize: 13)),
            ),
            const SizedBox(height: 10),
            AuthSecondaryButton(
              leading: const Icon(Icons.login, color: Colors.white70, size: 18),
              label: 'Log In',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ],
        ),
      ),
    );
  }
}