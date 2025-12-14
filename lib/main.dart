import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:habitdo/core/themes/app_theme.dart';
import 'package:habitdo/core/themes/theme_provider.dart';
import 'package:habitdo/presentation/app/app_router.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Lock orientation (optional)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const HabitDoApp(),
    ),
  );
}

class HabitDoApp extends StatelessWidget {
  const HabitDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GetMaterialApp(
      title: 'HabitDo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // ✅ GoRouter is wrapped here as a child widget
      home: const RouterWrapper(),
    );
  }
}

class RouterWrapper extends StatelessWidget {
  const RouterWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Simply use GoRouter’s built-in router widget
    return MaterialApp.router(
      routerConfig: appRouter, // 👈 your router from app_router.dart
      debugShowCheckedModeBanner: false,
    );
  }
}
