// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'upcoming_events_screen.dart';
import 'my_team_screen.dart';
import 'game_selection_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../services/team_service.dart';
import '../services/theme_service.dart';
import '../models/team.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  final TeamService _teamService = TeamService();
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _addTeam(Team team) {
    print(
      'Main navigation received team: ${team.name} with ${team.players.length} players',
    ); // Debug print
    _teamService.addTeam(team);
    setState(() {
      _currentIndex = 2; // Switch to My Team screen (now at index 2)
    });
    print('Switched to My Team screen'); // Debug print
  }

  void _navigateToHome() {
    setState(() {
      _currentIndex = 0; // Switch to Home tab (Upcoming Events)
    });
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return UpcomingEventsScreen(onHomePressed: _navigateToHome);
      case 1:
        return GameSelectionScreen(
          onSave: _addTeam,
          onHomePressed: _navigateToHome,
        );
      case 2:
        return MyTeamScreen(
          teamService: _teamService,
          onHomePressed: _navigateToHome,
        );
      case 3:
        return ScheduleScreen(onHomePressed: _navigateToHome);
      case 4:
        return SettingsScreen(onHomePressed: _navigateToHome);
      default:
        return UpcomingEventsScreen(onHomePressed: _navigateToHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back to login screen
        // Instead, you could show a confirmation dialog or do nothing
        return false;
      },
      child: AnimatedBuilder(
        animation: _themeService,
        builder: (context, child) {
          return Scaffold(
            body: _getCurrentScreen(),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor:
                  _themeService.isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
              selectedItemColor: const Color(0xFF2196F3),
              unselectedItemColor:
                  _themeService.isDarkMode ? Colors.white54 : Colors.grey[600],
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.app_registration),
                  label: 'Registration',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group),
                  label: 'My Team',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'Schedule',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
