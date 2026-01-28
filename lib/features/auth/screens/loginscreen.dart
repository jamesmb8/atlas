import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isValid =>
      _emailController.text.trim().isNotEmpty &&
          _passwordController.text.trim().length >= 6;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_isValid || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in ✅')),
      );

      // TODO: Replace with your home/map screen route.
      // Navigator.pushReplacementNamed(context, '/home');

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F6F2);
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const accent = Color(0xFF9FC8B2);
    const border = Color(0xFFE3E4DE);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    color: primaryText,
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: _HeaderPill(text: 'Login')),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Welcome back",
                style: TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w400,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sign in to continue.",
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 28),

              _AtlasTextField(
                controller: _emailController,
                label: "Email",
                hintText: "you@example.com",
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                border: border,
                accent: accent,
                textColor: primaryText,
                secondaryText: secondaryText,
              ),
              const SizedBox(height: 14),
              _AtlasTextField(
                controller: _passwordController,
                label: "Password",
                hintText: "Your password",
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                border: border,
                accent: accent,
                textColor: primaryText,
                secondaryText: secondaryText,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: secondaryText,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _showResetPasswordSheet,
                  child: const Text(
                    "Forgot password?",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: secondaryText,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isValid && !_isLoading) ? _login : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor: border,
                    foregroundColor: primaryText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    "Log in",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    "Don’t have an account? Sign up",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetPasswordSheet() {
    final resetController = TextEditingController(text: _emailController.text.trim());

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF7F6F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        const primaryText = Color(0xFF1F1F1F);
        const secondaryText = Color(0xFF6B6E6A);
        const accent = Color(0xFF9FC8B2);
        const border = Color(0xFFE3E4DE);

        bool sending = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> send() async {
              final email = resetController.text.trim();
              if (email.isEmpty || sending) return;

              setSheetState(() => sending = true);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent ✅')),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Failed to send reset email.')),
                );
              } finally {
                setSheetState(() => sending = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Reset password",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AtlasTextField(
                    controller: resetController,
                    label: "Email",
                    hintText: "you@example.com",
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => send(),
                    border: border,
                    accent: accent,
                    textColor: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: sending ? null : send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        disabledBackgroundColor: border,
                        foregroundColor: primaryText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        "Send reset link",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill({required this.text});

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE3E4DE);
    const textColor = Color(0xFF6B6E6A);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _AtlasTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final Color border;
  final Color accent;
  final Color textColor;
  final Color secondaryText;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final void Function(String)? onSubmitted;
  final Widget? suffix;

  const _AtlasTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.border,
    required this.accent,
    required this.textColor,
    required this.secondaryText,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: secondaryText),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: secondaryText.withOpacity(0.7)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.45),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
