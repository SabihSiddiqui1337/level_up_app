// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../services/event_service.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../models/event.dart';
import '../widgets/custom_app_bar.dart';
import 'team_detail_screen.dart';
import 'pickleball_team_detail_screen.dart';
import 'team_registration_screen.dart';

class MyTeamScreen extends StatefulWidget {
  final TeamService teamService;
  final PickleballTeamService pickleballTeamService;
  final VoidCallback? onHomePressed;

  const MyTeamScreen({
    super.key,
    required this.teamService,
    required this.pickleballTeamService,
    this.onHomePressed,
  });

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final _authService = AuthService();
  final _eventService = EventService();
  
  final Map<String, List<Team>> _teamsBySport = {};
  final Map<String, List<PickleballTeam>> _pickleballTeamsBySport = {};
  List<String> _availableSports = [];
  final Map<String, Event> _eventsCache = {};
  String? _selectedSport;
  
  // Editing states
  final Map<String, TextEditingController> _editingControllers = {};
  final Map<String, bool> _isEditing = {};

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    // Dispose all editing controllers
    for (var controller in _editingControllers.values) {
      controller.dispose();
    }
    _editingControllers.clear();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    await widget.teamService.loadTeams();
    await widget.pickleballTeamService.loadTeams();
    await _eventService.initialize();
    
    // Cache events
    _eventsCache.clear();
    for (var event in _eventService.events) {
      _eventsCache[event.id] = event;
    }
    
    // Group teams by sport
    _teamsBySport.clear();
    final currentUser = _authService.currentUser;
    final userTeams = widget.teamService.getTeamsForUser(currentUser?.id);
    
    for (var team in userTeams) {
      final event = _eventsCache[team.eventId];
      if (event != null) {
        final sportName = event.sportName;
        if (!_teamsBySport.containsKey(sportName)) {
          _teamsBySport[sportName] = [];
        }
        _teamsBySport[sportName]!.add(team);
      }
    }
    
    // Group pickleball teams by sport
    _pickleballTeamsBySport.clear();
    final userPickleballTeams = widget.pickleballTeamService.getTeamsForUser(currentUser?.id);
    
    for (var team in userPickleballTeams) {
      final event = _eventsCache[team.eventId];
      if (event != null) {
        final sportName = event.sportName;
        if (!_pickleballTeamsBySport.containsKey(sportName)) {
          _pickleballTeamsBySport[sportName] = [];
        }
        _pickleballTeamsBySport[sportName]!.add(team);
      } else {
        if (!_pickleballTeamsBySport.containsKey('Pickleball')) {
          _pickleballTeamsBySport['Pickleball'] = [];
        }
        _pickleballTeamsBySport['Pickleball']!.add(team);
      }
    }
    
    // Combine all sports
    final allSports = <String>{};
    allSports.addAll(_teamsBySport.keys);
    allSports.addAll(_pickleballTeamsBySport.keys);
    _availableSports = allSports.toList()..sort();
    
    // Set selected sport to first one if available
    if (_availableSports.isNotEmpty && _selectedSport == null) {
      _selectedSport = _availableSports.first;
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  List<dynamic> _getTeamsForSport(String sportName) {
    final teams = <dynamic>[];
    
    if (_teamsBySport.containsKey(sportName)) {
      teams.addAll(_teamsBySport[sportName]!);
    }
    
    if (_pickleballTeamsBySport.containsKey(sportName)) {
      teams.addAll(_pickleballTeamsBySport[sportName]!);
    }
    
    return teams;
  }

  IconData _getSportIcon(String sportName) {
    final lowerSport = sportName.toLowerCase();
    if (lowerSport.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lowerSport.contains('pickleball')) {
      return Icons.sports_tennis;
    } else if (lowerSport.contains('soccer')) {
      return Icons.sports_soccer;
    } else if (lowerSport.contains('volleyball')) {
      return Icons.sports_volleyball;
    }
    return Icons.sports;
  }

  Color _getSportColor(String sportName) {
    final lowerSport = sportName.toLowerCase();
    if (lowerSport.contains('basketball')) {
      return const Color(0xFF2196F3);
    } else if (lowerSport.contains('pickleball')) {
      return const Color(0xFF38A169);
    } else if (lowerSport.contains('soccer')) {
      return const Color(0xFF607D8B);
    } else if (lowerSport.contains('volleyball')) {
      return const Color(0xFF9B59B6);
    }
    return const Color(0xFF2196F3);
  }

  void _startEditingTeam(dynamic team) {
    final teamId = team.id;
    setState(() {
      _isEditing[teamId] = true;
      if (!_editingControllers.containsKey(teamId)) {
        _editingControllers[teamId] = TextEditingController(text: team.name);
      }
    });
  }

  void _cancelEditing(String teamId) {
    setState(() {
      _isEditing[teamId] = false;
    });
  }

  Future<void> _saveTeamName(dynamic team) async {
    final teamId = team.id;
    final newName = _editingControllers[teamId]?.text.trim() ?? '';
    
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newName == team.name) {
      _cancelEditing(teamId);
      return;
    }

    try {
      if (team is Team) {
        final updatedTeam = Team(
          id: team.id,
          name: newName,
          coachName: team.coachName,
          coachPhone: team.coachPhone,
          coachEmail: team.coachEmail,
          coachAge: team.coachAge,
          players: team.players,
          registrationDate: team.registrationDate,
          division: team.division,
          createdByUserId: team.createdByUserId,
          isPrivate: team.isPrivate,
          eventId: team.eventId,
        );
        await widget.teamService.updateTeam(updatedTeam);
      } else if (team is PickleballTeam) {
        final updatedTeam = PickleballTeam(
          id: team.id,
          name: newName,
          coachName: team.coachName,
          coachPhone: team.coachPhone,
          coachEmail: team.coachEmail,
          players: team.players,
          registrationDate: team.registrationDate,
          division: team.division,
          createdByUserId: team.createdByUserId,
          isPrivate: team.isPrivate,
          eventId: team.eventId,
        );
        await widget.pickleballTeamService.updateTeam(updatedTeam);
      }

      setState(() {
        _isEditing[teamId] = false;
      });

      await _loadTeams();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team name updated to "$newName"'),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToTeamDetail(Team team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailScreen(
          team: team,
          onUpdate: (updatedTeam) async {
            await widget.teamService.updateTeam(updatedTeam);
            // Refresh teams list after update
            if (mounted) {
              await _loadTeams();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Team "${updatedTeam.name}" updated successfully'),
                  backgroundColor: const Color(0xFF38A169),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          onDelete: (teamId) async {
            await widget.teamService.deleteTeam(teamId);
            // Refresh teams list after deletion
            if (mounted) {
              await _loadTeams();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Team deleted successfully'),
                  backgroundColor: Color(0xFF38A169),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    ).then((_) {
      // Refresh when returning from detail screen
      if (mounted) {
        _loadTeams();
      }
    });
  }

  void _navigateToPickleballTeamDetail(PickleballTeam team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickleballTeamDetailScreen(
          team: team,
          onUpdate: (updatedTeam) async {
            await widget.pickleballTeamService.updateTeam(updatedTeam);
            // Refresh teams list after update
            if (mounted) {
              await _loadTeams();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Team "${updatedTeam.name}" updated successfully'),
                  backgroundColor: const Color(0xFF38A169),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          onDelete: (teamId) async {
            await widget.pickleballTeamService.deleteTeam(teamId);
            // Refresh teams list after deletion
            if (mounted) {
              await _loadTeams();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Team deleted successfully'),
                  backgroundColor: Color(0xFF38A169),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    ).then((_) {
      // Refresh when returning from detail screen
      if (mounted) {
        _loadTeams();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final teams = _selectedSport != null ? _getTeamsForSport(_selectedSport!) : <dynamic>[];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Column(
        children: [
          // Modern Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2196F3),
                  const Color(0xFF1976D2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.group,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Teams',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${teams.length} team${teams.length != 1 ? 's' : ''} registered',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_availableSports.length > 1) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Select Sport',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _availableSports.map((sport) {
                            final isSelected = _selectedSport == sport;
                            final sportColor = _getSportColor(sport);
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSport = sport;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: sportColor,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getSportIcon(sport),
                                        color: isSelected
                                            ? sportColor
                                            : Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        sport,
                                        style: TextStyle(
                                          color: isSelected
                                              ? sportColor
                                              : Colors.white,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Teams List
          Expanded(
            child: _availableSports.isEmpty
                ? _buildEmptyState()
                : _selectedSport == null
                    ? const Center(child: Text('Select a sport'))
                    : teams.isEmpty
                        ? _buildEmptyStateForSport(_selectedSport!)
                        : RefreshIndicator(
                            onRefresh: _loadTeams,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: teams.length,
                              itemBuilder: (context, index) {
                                final team = teams[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: team is Team
                                      ? _buildModernTeamCard(team, _selectedSport!)
                                      : _buildModernPickleballTeamCard(
                                          team as PickleballTeam, _selectedSport!),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTeamCard(Team team, String sportName) {
    final sportColor = _getSportColor(sportName);
    final sportIcon = _getSportIcon(sportName);
    final teamId = team.id;
    final isEditing = _isEditing[teamId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEditing ? null : () => _navigateToTeamDetail(team),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sportColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(sportIcon, color: sportColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isEditing)
                            TextField(
                              controller: _editingControllers[teamId],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              autofocus: true,
                            )
                          else
                            Text(
                              team.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  team.coachName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isEditing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _saveTeamName(team),
                            tooltip: 'Save',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _cancelEditing(teamId),
                            tooltip: 'Cancel',
                          ),
                        ],
                      )
                    else
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _startEditingTeam(team);
                          } else if (value == 'view') {
                            _navigateToTeamDetail(team);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit Name'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 20),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoBadge(
                      Icons.people,
                      '${team.players.length + 1}',
                      const Color(0xFF38A169),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoBadge(
                      Icons.category,
                      team.division,
                      sportColor,
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

  Widget _buildModernPickleballTeamCard(PickleballTeam team, String sportName) {
    final sportColor = _getSportColor(sportName);
    final sportIcon = _getSportIcon(sportName);
    final teamId = team.id;
    final isEditing = _isEditing[teamId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEditing ? null : () => _navigateToPickleballTeamDetail(team),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sportColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(sportIcon, color: sportColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isEditing)
                            TextField(
                              controller: _editingControllers[teamId],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              autofocus: true,
                            )
                          else
                            Text(
                              team.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  team.coachName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isEditing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _saveTeamName(team),
                            tooltip: 'Save',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _cancelEditing(teamId),
                            tooltip: 'Cancel',
                          ),
                        ],
                      )
                    else
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _startEditingTeam(team);
                          } else if (value == 'view') {
                            _navigateToPickleballTeamDetail(team);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit Name'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 20),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoBadge(
                      Icons.people,
                      '${team.players.length + 1}',
                      const Color(0xFF38A169),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoBadge(
                      Icons.category,
                      team.division,
                      sportColor,
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

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_basketball,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Teams Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Register your first team to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateForSport(String sport) {
    final sportIcon = _getSportIcon(sport);
    final sportColor = _getSportColor(sport);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: sportColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                sportIcon,
                size: 64,
                color: sportColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No $sport Teams',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t registered any teams for $sport yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
