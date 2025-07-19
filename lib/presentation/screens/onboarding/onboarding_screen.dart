// TODO Implement this library.
import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HabitDo'), centerTitle: true),
      body: const Center(
        child: Text('Onboarding', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
