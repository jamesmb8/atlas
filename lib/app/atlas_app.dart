import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:atlas/app/screens/home_screen.dart';
import 'package:atlas/app/screens/landing_screen.dart';
import 'package:atlas/app/screens/route_options_screen.dart';
import 'package:flutter/material.dart';
import '../features/auth/screens/appleroutetestscreen.dart';
import '../features/auth/screens/signupnamescreen.dart';
import '../features/themes/atlas_theme.dart';

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AtlasTheme.light(),

      title: 'Atlas',
      home: const LandingScreen()

    );
  }
}
