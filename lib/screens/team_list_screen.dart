import 'package:flutter/material.dart';
import '../models/team.dart';
import 'team_registration_screen.dart';
import 'team_detail_screen.dart';
import '../keys/team_screen/team_screen_keys.dart';
import '../services/team_service.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final List<Team> _teams = [];
  final TeamService _teamService = TeamService();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    setState(() {
      _teams.clear();
      _teams.addAll(_teamService.teams);
    });
  }

  Future<void> _addTeam(Team team) async {
    await _teamService.addTeam(team);
    setState(() {
      _teams.clear();
      _teams.addAll(_teamService.teams);
    });
  }

  Future<void> _updateTeam(Team updatedTeam) async {
    await _teamService.updateTeam(updatedTeam);
    setState(() {
      _teams.clear();
      _teams.addAll(_teamService.teams);
    });
  }

  Future<void> _deleteTeam(String teamId) async {
    await _teamService.deleteTeam(teamId);
    setState(() {
      _teams.clear();
      _teams.addAll(_teamService.teams);
    });
  }

  void _navigateToRegistration({Team? team}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TeamRegistrationScreen(
              team: team,
              onSave:
                  team == null
                      ? _addTeam
                      : (updatedTeam) {
                        _updateTeam(updatedTeam);
                        Navigator.pop(context); // Navigate back to team list
                      },
            ),
      ),
    );
  }

  void _navigateToTeamDetail(Team team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TeamDetailScreen(
              team: team,
              onUpdate: _updateTeam,
              onDelete: _deleteTeam,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(TeamScreenKeys.appTitle),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child:
            _teams.isEmpty
                ? _buildEmptyState()
                : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.sports_basketball,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            TeamScreenKeys.registeredTeams,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_teams.length} ${_teams.length == 1 ? TeamScreenKeys.teamsCount : TeamScreenKeys.teamsCountPlural} ${TeamScreenKeys.teamsRegistered}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToRegistration(),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(TeamScreenKeys.registerTeam),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_basketball,
              size: 120,
              color: const Color(0xFF90CAF9),
            ),
            const SizedBox(height: 24),
            Text(
              TeamScreenKeys.noTeamsRegistered,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              TeamScreenKeys.noTeamsMessage,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _navigateToRegistration(),
              icon: const Icon(Icons.add),
              label: const Text(TeamScreenKeys.registerFirstTeam),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
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
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE3F2FD),
                    radius: 25,
                    child: Icon(
                      Icons.sports_basketball,
                      color: const Color(0xFF1976D2),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1976D2),
                          ),
                        ),
                        Text(
                          '${TeamScreenKeys.coachPrefix} ${team.coachName}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _navigateToRegistration(team: team);
                          break;
                        case 'delete':
                          _showDeleteDialog(team);
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFF2196F3)),
                                SizedBox(width: 8),
                                Text(TeamScreenKeys.edit),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Color(0xFFE53E3E)),
                                SizedBox(width: 8),
                                Text(TeamScreenKeys.delete),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.category,
                    team.division,
                    const Color(0xFF2196F3),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.people,
                    '${team.players.length} ${TeamScreenKeys.playersCount}',
                    const Color(0xFF38A169),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${TeamScreenKeys.registeredPrefix} ${_formatDate(team.registrationDate)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
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
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Team team) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(TeamScreenKeys.deleteTeamTitle),
            content: Text(
              '${TeamScreenKeys.deleteTeamMessage} "${team.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(TeamScreenKeys.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  _deleteTeam(team.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(TeamScreenKeys.teamDeletedSuccess),
                      backgroundColor: const Color(0xFF38A169),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53E3E),
                  foregroundColor: Colors.white,
                ),
                child: const Text(TeamScreenKeys.deleteButton),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}
