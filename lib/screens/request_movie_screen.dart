import 'package:flutter/material.dart';
import 'package:tulabe/screens/login_screen.dart';
import '../theme/app_colors.dart';

/// Request a Movie — mirrors the web /request-movie.
/// UI only: a form with a success confirmation state.
class RequestMovieScreen extends StatefulWidget {
  const RequestMovieScreen({super.key});

  @override
  State<RequestMovieScreen> createState() => _RequestMovieScreenState();
}

class _RequestMovieScreenState extends State<RequestMovieScreen> {
  final _movieController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _movieController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_movieController.text.trim().isEmpty) return;
    setState(() => _submitted = true);
  }

  void _reset() {
    setState(() {
      _submitted = false;
      _movieController.clear();
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0118),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white60),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _submitted ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.movie_filter_outlined, color: AppColors.primary, size: 56),
        const SizedBox(height: 16),
        const Text(
          'REQUEST A MOVIE',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          "Can't find what you're looking for? Ask us!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _movieController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: AppColors.primary,
          decoration: _inputDecoration('e.g. Avengers: Endgame'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notesController,
          maxLines: 4,
          minLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: AppColors.primary,
          decoration: _inputDecoration('Year, VJ, language, any extra details…'),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _submit,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 14)],
            ),
            alignment: Alignment.center,
            child: const Text('SUBMIT REQUEST',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: AppColors.primary, size: 56),
        const SizedBox(height: 20),
        const Text(
          'Request Sent!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          "We've received your movie request and will let you know the moment it's available on Tulabe.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _reset,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF262A30),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('REQUEST ANOTHER MOVIE',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text('Sign in to track your request', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF0B0D11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A3A4A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}