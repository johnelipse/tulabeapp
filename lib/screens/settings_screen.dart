import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/controllers/push_controller.dart';
import '../theme/app_colors.dart';

/// Profile Settings screen — mirrors the web /settings page.
/// Profile, change password, and sign-out are wired to the Go API
/// (`/auth/me` PATCH, `/auth/change-password`); telegram/support stay UI-only.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _currentPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = AuthController.instance.user;
    _firstName.text = user?.firstName ?? '';
    _lastName.text = user?.lastName ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _currentPwd.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _saveProfile() async {
    final f = _firstName.text.trim();
    final l = _lastName.text.trim();
    if (f.isEmpty && l.isEmpty) {
      _showToast('Please enter a name');
      return;
    }
    final ok = await AuthController.instance.updateProfile(firstName: f, lastName: l);
    if (!mounted) return;
    if (ok) {
      _showToast('Profile updated');
    } else {
      _showToast(AuthController.instance.error ?? 'Could not update profile');
    }
  }

  Future<void> _changePassword() async {
    if (_newPwd.text != _confirmPwd.text) {
      _showToast("New passwords don't match");
      return;
    }
    if (_newPwd.text.length < 8) {
      _showToast('Password must be at least 8 characters');
      return;
    }
    final ok = await AuthController.instance.changePassword(
      currentPassword: _currentPwd.text,
      newPassword: _newPwd.text,
    );
    if (!mounted) return;
    if (ok) {
      _currentPwd.clear();
      _newPwd.clear();
      _confirmPwd.clear();
      _showToast('Password changed successfully');
    } else {
      _showToast(AuthController.instance.error ?? 'Could not change password');
    }
  }

  Future<void> _signOut() async {
    await AuthController.instance.logout();
    if (!mounted) return;
    _showToast('Signed out');
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white60, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'ACCOUNT',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              const Text(
                'PROFILE SETTINGS',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 20),
              // Profile
              _SectionCard(
                icon: Icons.person_outline,
                title: 'Profile',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AvatarRow(
                      initial: AuthController.instance.user?.initial ?? 'T',
                      email: AuthController.instance.user?.email ?? '',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _TextLabel('FIRST NAME'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextLabel('LAST NAME'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(controller: _firstName, hint: 'John'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextField(controller: _lastName, hint: 'Doe'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PrimaryButton(label: 'Save Profile', onTap: _saveProfile),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Password
              _SectionCard(
                icon: Icons.lock_outline,
                title: 'Change Password',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TextLabel('CURRENT PASSWORD'),
                    const SizedBox(height: 6),
                    _PasswordField(controller: _currentPwd, hint: 'Enter current password'),
                    const SizedBox(height: 14),
                    _TextLabel('NEW PASSWORD'),
                    const SizedBox(height: 6),
                    _PasswordField(controller: _newPwd, hint: 'At least 8 characters'),
                    const SizedBox(height: 14),
                    _TextLabel('CONFIRM NEW PASSWORD'),
                    const SizedBox(height: 6),
                    _PasswordField(controller: _confirmPwd, hint: 'Repeat new password'),
                    const SizedBox(height: 16),
                    _PrimaryButton(label: 'Change Password', onTap: _changePassword),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Push notifications
              _NotificationsCard(),
              const SizedBox(height: 20),
              // Danger zone
              _SectionCard(
                icon: Icons.shield_outlined,
                title: 'Account',
                danger: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need help or want to delete your account? Contact us on Telegram.',
                      style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Contact Support',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _signOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'SIGN OUT',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final bool danger;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: danger ? const Color(0x1AFF5252) : Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: danger ? const Color(0x1AFF5252) : Colors.white10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: danger ? Colors.redAccent : AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final String initial;
  final String email;
  const _AvatarRow({required this.initial, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.primary),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.w700),
              ),
            ),
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: const Color(0xFF0A0118), width: 2),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 11),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Signed in as', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                email.isEmpty ? 'Not signed in' : email,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextLabel extends StatelessWidget {
  final String text;
  const _TextLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _TextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const _PasswordField({required this.controller, required this.hint});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: widget.controller,
        obscureText: _obscured,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          suffixIcon: IconButton(
            icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.white38, size: 18),
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PushController.instance,
      builder: (context, _) {
        final push = PushController.instance;
        return _SectionCard(
          icon: Icons.notifications_none,
          title: 'Notifications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Get alerted when new movies and series land on Tulabe.',
                style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      push.error ?? (push.enabled
                          ? 'Subscribed to broadcast notifications.'
                          : 'Turn on to subscribe your device.'),
                      style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: push.enabled,
                    onChanged: push.busy ? null : (value) => _toggle(context, value),
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: Colors.white12,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await PushController.instance.setEnabled(value);
    if (!value) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Notifications turned off', style: TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.black87,
        duration: Duration(seconds: 2),
      ));
    } else if (!ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          PushController.instance.error ?? 'Could not enable notifications',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 3),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Notifications enabled', style: TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.black87,
        duration: Duration(seconds: 2),
      ));
    }
  }
}