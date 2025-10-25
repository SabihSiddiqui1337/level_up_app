import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_app_bar.dart';
import 'sport_schedule_screen.dart';
import '../keys/schedule_screen/schedule_screen_keys.dart';

class ScheduleScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const ScheduleScreen({super.key, this.onHomePressed});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
  }

  Future<void> _loadExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool('schedule_expansion_state') ?? false;
      setState(() {
        _isExpanded = isExpanded;
      });
    } catch (e) {
      print('Error loading expansion state: $e');
    }
  }

  Future<void> _saveExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('schedule_expansion_state', _isExpanded);
    } catch (e) {
      print('Error saving expansion state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
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
                    ScheduleScreenKeys.screenTitle,
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
                          _saveExpansionState();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ScheduleScreenKeys.year2025,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.black54,
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
                                        ScheduleScreenKeys.basketball,
                                        const Color(0xFFE67E22), // Orange
                                        Icons.sports_basketball,
                                        ScheduleScreenKeys.basketballTournament,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSportCard(
                                        ScheduleScreenKeys.pickleball,
                                        const Color(0xFF38A169), // Green
                                        Icons.sports_tennis,
                                        ScheduleScreenKeys.pickleballTournament,
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
      ),
    );
  }

  Widget _buildSportCard(
    String sportName,
    Color color,
    IconData icon,
    String tournamentTitle,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
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
