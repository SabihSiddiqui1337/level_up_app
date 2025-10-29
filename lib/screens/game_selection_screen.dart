import 'package:flutter/material.dart';
import 'team_registration_screen.dart';
import 'pickleball_team_registration_screen.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../widgets/custom_app_bar.dart';

class GameSelectionScreen extends StatefulWidget {
  final Function(Team) onSave;
  final Function(PickleballTeam)? onSavePickleball;
  final VoidCallback? onHomePressed;

  const GameSelectionScreen({
    super.key,
    required this.onSave,
    this.onSavePickleball,
    this.onHomePressed,
  });

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  final EventService _eventService = EventService();
  List<Event> _events = [];
  List<String> _sportNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    await _eventService.initialize();
    setState(() {
      _events = _eventService.upcomingEvents;
      // Get unique sport names from events
      _sportNames = _events.map((e) => e.sportName).toSet().toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a sport to register your team:',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(child: _buildRegularGameSelection()),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularGameSelection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sportNames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sports available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check upcoming events for available sports',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _sportNames.length,
      itemBuilder: (context, index) {
        final sportName = _sportNames[index];
        final icon = _getSportIcon(sportName);
        final color = _getSportColor(index);

        return _buildGameCard(context, sportName, icon, color, () {
          if (sportName.toLowerCase().contains('pickleball')) {
            _navigateToPickleballRegistration(context);
          } else {
            _navigateToTeamRegistration(context, sportName);
          }
        });
      },
    );
  }

  IconData _getSportIcon(String sportName) {
    final lowerSport = sportName.toLowerCase();
    if (lowerSport.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lowerSport.contains('pickleball') ||
        lowerSport.contains('tennis')) {
      return Icons.sports_tennis;
    } else if (lowerSport.contains('soccer') ||
        lowerSport.contains('football')) {
      return Icons.sports_soccer;
    } else if (lowerSport.contains('volleyball')) {
      return Icons.sports_volleyball;
    } else {
      return Icons.sports;
    }
  }

  Color _getSportColor(int index) {
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF38A169), // Green
      const Color(0xFFE67E22), // Orange
      const Color(0xFF9B59B6), // Purple
      const Color(0xFFE74C3C), // Red
      const Color(0xFF3498DB), // Light Blue
    ];
    return colors[index % colors.length];
  }

  Widget _buildGameCard(
    BuildContext context,
    String gameName,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                gameName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTeamRegistration(BuildContext context, String gameType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TeamRegistrationScreen(
              onSave: (team) {
                // Add game type to team
                final teamWithGame = Team(
                  id: team.id,
                  name: team.name,
                  coachName: team.coachName,
                  coachPhone: team.coachPhone,
                  coachEmail: team.coachEmail,
                  coachAge: team.coachAge,
                  players: team.players,
                  registrationDate: team.registrationDate,
                  division: team.division,
                );

                widget.onSave(teamWithGame);
                Navigator.pop(context); // Go back to home screen
              },
            ),
      ),
    );
  }

  void _navigateToPickleballRegistration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PickleballTeamRegistrationScreen(
              onSave: (team) {
                if (widget.onSavePickleball != null) {
                  widget.onSavePickleball!(team);
                }
                Navigator.pop(context); // Go back to home screen
              },
            ),
      ),
    );
  }
}
