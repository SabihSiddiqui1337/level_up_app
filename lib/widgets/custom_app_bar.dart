import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onHomePressed;

  const CustomAppBar({super.key, this.onHomePressed});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black, // Black background
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: Colors.black, // Solid black background
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Spacer(),
                // Logo
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/level_up_sport.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.sports_basketball,
                              color: Color(0xFF2196F3),
                              size: 40,
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level Up Sports',
                          style: TextStyle(
                            color: const Color(0xFF2196F3),
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Right Icons
                Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: const Color(0xFF2196F3),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onHomePressed,
                      child: Icon(
                        Icons.home,
                        color: const Color(0xFFE67E22),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
