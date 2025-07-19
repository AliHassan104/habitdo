import 'package:flutter/material.dart';
import 'package:habitdo/presentation/shared/widgets/bottom_navigation.dart';
import 'package:provider/provider.dart';
import 'package:habitdo/core/themes/theme_provider.dart';
import 'package:habitdo/presentation/shared/widgets/common_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return BottomNavScaffold(
      selectedIndex: 1, // Settings tab
      showHome: true, // Show home icon in AppBar
      child: Scaffold(
        //appBar: const CommonAppBar(title: 'Settings'),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
              ),
              const Divider(),

              /// ✅ Logout Button
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  context.go('/signin'); // Redirect to Sign In
                },
              ),

              const Divider(),
              const Text('More settings coming soon...'),
            ],
          ),
        ),
      ),
    );
  }
}
