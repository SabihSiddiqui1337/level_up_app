import 'package:flutter/material.dart';
import 'team_registration_screen.dart';
import 'pickleball_team_registration_screen.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../widgets/custom_app_bar.dart';

class GameSelectionScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(onHomePressed: onHomePressed),
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
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildGameCard(
                    context,
                    'Basketball',
                    Icons.sports_basketball,
                    const Color(0xFF2196F3),
                    () => _navigateToTeamRegistration(context, 'Basketball'),
                  ),
                  _buildGameCard(
                    context,
                    'Pickleball',
                    Icons.sports_tennis,
                    const Color(0xFF38A169),
                    () => _navigateToPickleballRegistration(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

                onSave(teamWithGame);
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
                if (onSavePickleball != null) {
                  onSavePickleball!(team);
                }
                Navigator.pop(context); // Go back to home screen
              },
            ),
      ),
    );
  }
}
