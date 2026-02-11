import 'package:atlas/app/screens/home_screen.dart';
import 'package:atlas/app/screens/landing_screen.dart';
import 'package:flutter/material.dart';
import '../features/auth/screens/signupnamescreen.dart';

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'atlas',
      home: HomeScreen(),
    );
  }
}
