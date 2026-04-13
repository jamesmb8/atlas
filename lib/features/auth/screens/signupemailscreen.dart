import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../app/screens/home_screen.dart';

class SignUpEmailScreen extends StatefulWidget {
  final String firstName;
  final String surname;

  const SignUpEmailScreen({
    super.key,
    required this.firstName,
    required this.surname,
  });

  @override
  State<SignUpEmailScreen> createState() => _SignUpEmailScreenState();
}

class _SignUpEmailScreenState extends State<SignUpEmailScreen> {
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

  Future<void> _createAccount() async {
    if (!_isValid || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 1) Create Auth user
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'Account creation failed. Please try again.',
        );
      }

      // 2) Optional: set display name in Firebase Auth
      await user.updateDisplayName("${widget.firstName} ${widget.surname}");

      // 3) Create Firestore user doc (minimal model)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'firstName': widget.firstName,
        'surname': widget.surname,
        'displayName': "${widget.firstName} ${widget.surname}",
        'provider': 'password',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );

      // Example placeholder:
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
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is disabled in Firebase.';
      default:
        return e.message ?? 'Sign up failed. Please try again.';
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
                  const Expanded(child: _ProgressPill(stepText: '2/2')),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "Create your account",
                style: TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w400,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We’ll use this to save your places and preferences.",
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
                hintText: "At least 6 characters",
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createAccount(),
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

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isValid && !_isLoading) ? _createAccount : null,
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
                    "Create account",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "By continuing, you agree to basic account creation.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final String stepText;
  const _ProgressPill({required this.stepText});

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE3E4DE);
    const accent = Color(0xFF9FC8B2);
    const textColor = Color(0xFF6B6E6A);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              child: LinearProgressIndicator(
                value: 1.0,
                minHeight: 6,
                backgroundColor: border,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '2/2',
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w400),
          ),
        ],
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
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
