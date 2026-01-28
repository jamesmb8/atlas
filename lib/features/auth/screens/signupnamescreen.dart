import 'package:flutter/material.dart';
import 'signupemailscreen.dart';
class SignUpNameScreen extends StatefulWidget {
  const SignUpNameScreen({super.key});

  @override
  State<SignUpNameScreen> createState() => _SignUpNameScreenState();
}

class _SignUpNameScreenState extends State<SignUpNameScreen> {
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();

  bool get _isValid =>
      _firstNameController.text.trim().isNotEmpty &&
          _surnameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onChanged);
    _surnameController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (!_isValid) return;

    final firstName = _firstNameController.text.trim();
    final surname = _surnameController.text.trim();

    void _onContinue() {
      if (!_isValid) return;

      final firstName = _firstNameController.text.trim();
      final surname = _surnameController.text.trim();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignUpEmailScreen(firstName: firstName, surname: surname),
        ),
      );
    }


    debugPrint('First name: $firstName, Surname: $surname');
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
              // Top row: back + progress
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    color: primaryText,
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProgressPill(
                      currentStep: 1,
                      totalSteps: 2,
                      border: border,
                      accent: accent,
                      textColor: secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "What’s your name?",
                style: TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w400, // LINE Seed JP Regular vibe
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This helps personalise your Atlas experience.",
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 28),

              _AtlasTextField(
                controller: _firstNameController,
                label: "First name",
                hintText: "Joe",
                border: border,
                accent: accent,
                textColor: primaryText,
                secondaryText: secondaryText,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _AtlasTextField(
                controller: _surnameController,
                label: "Surname",
                hintText: "Bloggs",
                border: border,
                accent: accent,
                textColor: primaryText,
                secondaryText: secondaryText,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onContinue(),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isValid ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor: border,
                    foregroundColor: primaryText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "You can change this later.",
                  style: const TextStyle(
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
  final int currentStep;
  final int totalSteps;
  final Color border;
  final Color accent;
  final Color textColor;

  const _ProgressPill({
    required this.currentStep,
    required this.totalSteps,
    required this.border,
    required this.accent,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: border,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "$currentStep/$totalSteps",
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
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
  final void Function(String)? onSubmitted;

  const _AtlasTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.border,
    required this.accent,
    required this.textColor,
    required this.secondaryText,
    required this.textInputAction,
    this.onSubmitted,
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
          textInputAction: textInputAction,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
