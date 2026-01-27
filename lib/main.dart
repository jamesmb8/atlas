import 'package:flutter/material.dart';



void main() {
  runApp(const AtlasApp());
}

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'atlas',
      home: SizedBox.shrink(),
    );
  }
}