// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'upcoming_events_screen.dart';
import 'my_team_screen.dart';
import 'game_selection_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();

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

  void _addPickleballTeam(PickleballTeam team) {
    print(
      'Main navigation received pickleball team: ${team.name} with ${team.players.length} players',
    ); // Debug print
    _pickleballTeamService.addTeam(team);
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
          onSavePickleball: _addPickleballTeam,
          onHomePressed: _navigateToHome,
        );
      case 2:
        return MyTeamScreen(
          teamService: _teamService,
          pickleballTeamService: _pickleballTeamService,
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
      child: Scaffold(
        body: _getCurrentScreen(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.app_registration),
              label: 'Registration',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'My Team'),
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
      ),
    );
  }
}
