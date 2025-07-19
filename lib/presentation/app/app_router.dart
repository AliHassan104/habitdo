import 'package:flutter/material.dart';
import 'package:habitdo/presentation/screens/add_edit/add_edit_screen.dart';
import 'package:habitdo/presentation/screens/authentication/signup.dart';
import 'package:habitdo/presentation/screens/dashboard/dashboard.dart';
import 'package:habitdo/presentation/screens/home/home_screen.dart';
import 'package:habitdo/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:habitdo/presentation/screens/settings/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitdo/presentation/screens/authentication/forgot_password.dart';
import 'package:habitdo/presentation/screens/authentication/signin.dart';

// Screens
// Route names
class AppRoutes {
  static const home = 'home';
  static const addEdit = 'addEdit';
  static const settings = 'settings';
  static const onboarding = 'onboarding';
  static const dashboard = 'dashboard';
}

// Final router config
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  debugLogDiagnostics: true,

  routes: [
    GoRoute(
      path: '/signin',
      name: 'signin',
      pageBuilder:
          (context, state) => const MaterialPage(child: SignInScreen()),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      pageBuilder: (context, state) => MaterialPage(child: SignUpScreen()),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgotPassword',
      pageBuilder: (context, state) => MaterialPage(child: ForgotPassword()),
    ),

    GoRoute(
      path: '/home',
      name: AppRoutes.home,
      pageBuilder: (context, state) => const MaterialPage(child: HomeScreen()),
    ),
    GoRoute(
      path: '/add',
      name: AppRoutes.addEdit,
      pageBuilder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;

        return MaterialPage(
          child: AddEditScreen(
            habitId: args?['habitId'],
            existingTitle: args?['existingTitle'],
            existingDescription: args?['existingDescription'],
          ),
        );
      },
    ),

    GoRoute(
      path: '/settings',
      name: AppRoutes.settings,
      pageBuilder:
          (context, state) => const MaterialPage(child: SettingsScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      name: AppRoutes.dashboard,
      pageBuilder:
          (context, state) => const MaterialPage(child: DashboardScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      name: AppRoutes.onboarding,
      pageBuilder:
          (context, state) => const MaterialPage(child: OnboardingScreen()),
    ),
  ],

  /// 🚀 Redirect based on auth
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;

    final isAuthPage = [
      '/signin',
      '/signup',
      '/forgot-password',
    ].contains(state.uri.toString());

    // 🔒 If user is NOT logged in and trying to access a protected route
    if (user == null && !isAuthPage) return '/signin';

    // 🔐 If user is logged in and trying to access an auth page, redirect to home
    if (user != null && isAuthPage) return '/home';

    return null;
  },

  // Optional redirect logic
  //redirect: (context, state) async {
  // Simulate onboarding check
  // final isFirstLaunch = false; // Replace with actual logic
  // if (isFirstLaunch && state.location != '/onboarding') {
  //   return '/onboarding';
  // }
  // return null;
  //},

  // Handle 404s
  errorPageBuilder:
      (context, state) => MaterialPage(
        child: Scaffold(
          appBar: AppBar(title: const Text('Oops!')),
          body: Center(child: Text('Route not found: ${state.uri.toString()}')),
        ),
      ),
);
