// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'upcoming_events_screen.dart';
import 'my_team_screen.dart';
import 'game_selection_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'scoring_screen.dart';
import 'admin_panel_screen.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../services/auth_service.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../utils/role_utils.dart';

class NavigationItem {
  final Widget screen;
  final IconData icon;
  final String label;

  NavigationItem({
    required this.screen,
    required this.icon,
    required this.label,
  });
}

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
  final AuthService _authService = AuthService();

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
    final user = _authService.currentUser;
    final userRole = user?.role ?? 'user';

    // Get role-based navigation items
    final navigationItems = _getNavigationItems(userRole);

    if (_currentIndex >= navigationItems.length) {
      _currentIndex = 0;
    }

    final currentItem = navigationItems[_currentIndex];
    return currentItem.screen;
  }

  List<NavigationItem> _getNavigationItems(String userRole) {
    final baseItems = [
      NavigationItem(
        screen: UpcomingEventsScreen(onHomePressed: _navigateToHome),
        icon: Icons.event,
        label: 'Home',
      ),
      NavigationItem(
        screen: GameSelectionScreen(
          onSave: _addTeam,
          onSavePickleball: _addPickleballTeam,
          onHomePressed: _navigateToHome,
        ),
        icon: Icons.app_registration,
        label: 'Registration',
      ),
      NavigationItem(
        screen: MyTeamScreen(
          teamService: _teamService,
          pickleballTeamService: _pickleballTeamService,
          onHomePressed: _navigateToHome,
        ),
        icon: Icons.group,
        label: 'My Team',
      ),
      NavigationItem(
        screen: ScheduleScreen(onHomePressed: _navigateToHome),
        icon: Icons.schedule,
        label: 'Schedule',
      ),
    ];

    // Add role-specific items
    if (RoleUtils.canScore(userRole)) {
      baseItems.add(
        NavigationItem(
          screen: ScoringScreen(
            sportName: 'Basketball',
            teamService: _teamService,
            pickleballTeamService: _pickleballTeamService,
          ),
          icon: Icons.sports_score,
          label: 'Scoring',
        ),
      );
    }

    if (RoleUtils.isOwner(userRole)) {
      baseItems.add(
        NavigationItem(
          screen: const AdminPanelScreen(),
          icon: Icons.admin_panel_settings,
          label: 'Admin',
        ),
      );
    }

    // Always add settings at the end
    baseItems.add(
      NavigationItem(
        screen: SettingsScreen(onHomePressed: _navigateToHome),
        icon: Icons.settings,
        label: 'Settings',
      ),
    );

    return baseItems;
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final userRole = user?.role ?? 'user';
    final navigationItems = _getNavigationItems(userRole);

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
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items:
              navigationItems.asMap().entries.map((entry) {
                final item = entry.value;
                final isRegistration = item.label == 'Registration';

                return BottomNavigationBarItem(
                  icon: Icon(item.icon, size: isRegistration ? 20 : 24),
                  label: item.label,
                );
              }).toList(),
        ),
      ),
    );
  }
}
