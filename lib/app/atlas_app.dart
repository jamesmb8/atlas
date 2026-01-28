import 'package:flutter/material.dart';
import '../features/auth/screens/signupnamescreen.dart';

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      debugShowCheckedModeBanner: false,
      title: 'atlas',
      theme: ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF9FC8B2), // Atlas sage green
          selectionHandleColor: Color(0xFF9FC8B2),
        ),
      ),
      home: const SignUpNameScreen(),
    );
  }
}
