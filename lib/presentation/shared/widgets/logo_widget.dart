import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/logo.png',
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      ),
    );
  }
}
