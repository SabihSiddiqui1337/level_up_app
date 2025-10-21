// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../models/team.dart';
import '../widgets/custom_app_bar.dart';
import 'team_detail_screen.dart';

class MyTeamScreen extends StatefulWidget {
  final TeamService teamService;
  final VoidCallback? onHomePressed;

  const MyTeamScreen({
    super.key,
    required this.teamService,
    this.onHomePressed,
  });

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Demo data loading removed - teams will persist until app restart
  }

  List<Team> get _teams {
    final teams = widget.teamService.teams;
    print('My Team screen showing ${teams.length} teams'); // Debug print
    for (var team in teams) {
      print(
        'Team: ${team.name} has ${team.players.length} players',
      ); // Debug print
      print(
        'Team players in my team screen: ${team.players.map((p) => p.name).toList()}',
      ); // Debug print
    }
    return teams;
  }

  void _navigateToTeamDetail(Team team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TeamDetailScreen(
              team: team,
              onUpdate: (updatedTeam) {
                widget.teamService.updateTeam(updatedTeam);
                setState(() {});
              },
              onDelete: (teamId) {
                widget.teamService.deleteTeam(teamId);
                setState(() {});
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 25,
                              child: Text(
                                user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                style: TextStyle(
                                  color: const Color(0xFF2196F3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                  Text(
                                    user?.name ?? 'User',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user?.role.toUpperCase() ?? 'USER',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Teams',
                                '${_teams.length}',
                                Icons.sports_basketball,
                                const Color(0xFF2196F3),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Players',
                                '${_teams.fold(0, (sum, team) => sum + team.players.length)}',
                                Icons.people,
                                const Color(0xFF42A5F5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child:
                        _teams.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _teams.length,
                              itemBuilder: (context, index) {
                                final team = _teams[index];
                                return _buildTeamCard(team);
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_basketball, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No teams yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register your first team to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToTeamDetail(team),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sports_basketball,
                      color: Color(0xFF2196F3),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coach: ${team.coachName}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.people,
                    '${team.players.length} Players',
                    const Color(0xFF38A169),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.category,
                    team.division,
                    const Color(0xFF2196F3),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.calendar_today,
                    _formatDate(team.registrationDate),
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}
