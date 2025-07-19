// lib/presentation/screens/dashboard/dashboard.dart
import 'package:flutter/material.dart';
import 'package:habitdo/presentation/shared/widgets/bottom_navigation.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      selectedIndex: 0, // Dashboard tab selected
      showHome: true, // Show Home button in AppBar
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Habits Completed Today'),
                subtitle: const Text('3 of 5 habits completed'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // You can navigate or show more info
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.timeline, color: Colors.blue),
                title: const Text('Weekly Progress'),
                subtitle: const Text('Keep it up!'),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.orange),
                title: const Text('Monthly Stats'),
                subtitle: const Text('Consistency: 80%'),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
