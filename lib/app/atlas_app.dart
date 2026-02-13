import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:atlas/app/screens/home_screen.dart';
import 'package:atlas/app/screens/landing_screen.dart';
import 'package:atlas/app/screens/route_options_screen.dart';
import 'package:flutter/material.dart';
import '../features/auth/screens/signupnamescreen.dart';

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'atlas',
      home: RouteOptionsScreen(destinationName: "Sheffield Station", destination: LatLng(53.3771, -1.4632)),
    );
  }
}
