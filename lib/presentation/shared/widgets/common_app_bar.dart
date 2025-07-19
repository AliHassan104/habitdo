import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showHome;
  final VoidCallback? onCalendarTap;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showHome = true,
    this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      leading:
          showHome
              ? IconButton(
                icon: const Icon(Icons.home, color: Colors.grey),
                onPressed: null, // Disabled (already on home)
              )
              : IconButton(
                icon: const Icon(Icons.home),
                onPressed: () => context.go('/home'),
              ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: onCalendarTap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
