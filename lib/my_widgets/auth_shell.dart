import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Auth shell — mirrors the web AuthShell: a full-screen black background
/// with the Tulabe brand logo, a back button, and a centered auth card.
class AuthShell extends StatelessWidget {
  final Widget child;
  const AuthShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 2),
        children: [
          TextSpan(text: 'TU', style: TextStyle(color: AppColors.primary)),
          TextSpan(text: 'LABE', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const AuthCard({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AuthLogo()),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.1),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
        ),
        const SizedBox(height: 32),
        child,
      ],
    );
  }
}

const authInputDecoration = InputDecoration(
  hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
  filled: true,
  fillColor: Color(0xFF0B0D11),
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFF1A3A4A)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: AppColors.primary),
  ),
);

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: AppColors.primary,
      decoration: authInputDecoration.copyWith(hintText: hint),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const AuthPrimaryButton({super.key, required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 14)],
        ),
        alignment: Alignment.center,
        child: Text(
          loading ? 'SIGNING IN…' : label,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ),
    );
  }
}

class AuthSecondaryButton extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback onTap;
  const AuthSecondaryButton({super.key, required this.leading, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF090A0D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const PasswordField({super.key, required this.controller, required this.hint});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: AppColors.primary,
      decoration: authInputDecoration.copyWith(
        hintText: widget.hint,
        suffixIcon: IconButton(
          icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF9CA3AF), size: 18),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}