import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../services/theme_service.dart';
import 'sport_schedule_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const ScheduleScreen({super.key, this.onHomePressed});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ThemeService _themeService = ThemeService();
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: AnimatedBuilder(
        animation: _themeService,
        builder: (context, child) {
          final isDark = _themeService.isDarkMode;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    isDark
                        ? [const Color(0xFF1E1E1E), const Color(0xFF2A2A2A)]
                        : [Colors.grey[50]!, Colors.white],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Center(
                      child: Text(
                        'SCHEDULE-RESULTS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE67E22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Year Selector with Expandable Sports
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '2025',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Expandable Sports List
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child:
                                _isExpanded
                                    ? Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildSportCard(
                                            'Basketball',
                                            const Color(0xFFE67E22), // Orange
                                            Icons.sports_basketball,
                                            'BasketBall Tournament 2025',
                                            isDark,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildSportCard(
                                            'Pickleball',
                                            const Color(0xFF38A169), // Green
                                            Icons.sports_tennis,
                                            'Thanksgiving Picketball Tournament',
                                            isDark,
                                          ),
                                        ],
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSportCard(
    String sportName,
    Color color,
    IconData icon,
    String tournamentTitle,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SportScheduleScreen(
                  sportName: sportName,
                  tournamentTitle: tournamentTitle,
                  onHomePressed: widget.onHomePressed,
                ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Text(
                sportName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
