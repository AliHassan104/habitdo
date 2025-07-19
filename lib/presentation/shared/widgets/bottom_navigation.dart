import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavScaffold extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final bool showHome;

  const BottomNavScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
    this.showHome = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Add Habit',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.dashboard),
              color:
                  selectedIndex == 0
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
              onPressed: () => context.go('/dashboard'),
            ),
            const SizedBox(width: 48), // FAB space
            IconButton(
              icon: const Icon(Icons.settings),
              color:
                  selectedIndex == 1
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
              onPressed: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}
