// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../widgets/custom_app_bar.dart';
import 'team_detail_screen.dart';
import 'pickleball_team_detail_screen.dart';

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

class _MyTeamScreenState extends State<MyTeamScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;

  // Filter states
  String? _selectedBasketballDivision;
  String? _selectedPickleballDivision;
  String? _selectedDuprRating;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Add listener to update counts when tab changes
    _tabController.addListener(() {
      setState(() {});
    });
    // Load teams when screen initializes
    _loadTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    await widget.teamService.loadTeams();
    await widget.pickleballTeamService.loadTeams();
    if (mounted) {
      setState(() {
        // Trigger rebuild to show updated teams
      });
    }
  }

  List<Team> get _basketballTeams {
    final teams = widget.teamService.teams;
    print(
      'My Team screen showing ${teams.length} basketball teams',
    ); // Debug print
    return teams;
  }

  List<PickleballTeam> get _pickleballTeams {
    final teams = widget.pickleballTeamService.teams;
    print(
      'My Team screen showing ${teams.length} pickleball teams',
    ); // Debug print
    return teams;
  }

  // Get filtered basketball teams based on selected division
  List<Team> get _filteredBasketballTeams {
    final teams = widget.teamService.teams;
    if (_selectedBasketballDivision == null) return teams;
    return teams
        .where((team) => team.division == _selectedBasketballDivision)
        .toList();
  }

  // Get filtered pickleball teams based on selected division and DURP rating
  List<PickleballTeam> get _filteredPickleballTeams {
    final teams = widget.pickleballTeamService.teams;
    var filteredTeams = teams;

    // Filter by division
    if (_selectedPickleballDivision != null) {
      filteredTeams =
          filteredTeams
              .where((team) => team.division == _selectedPickleballDivision)
              .toList();
    }

    // Filter by DURP rating
    if (_selectedDuprRating != null) {
      filteredTeams =
          filteredTeams.where((team) {
            return team.players.any(
              (player) => player.duprRating == _selectedDuprRating,
            );
          }).toList();
    }

    return filteredTeams;
  }

  // Get available basketball divisions
  List<String> get _availableBasketballDivisions {
    final divisions =
        widget.teamService.teams.map((team) => team.division).toSet().toList();
    divisions.sort();
    return divisions;
  }

  // Get available pickleball divisions
  List<String> get _availablePickleballDivisions {
    final divisions =
        widget.pickleballTeamService.teams
            .map((team) => team.division)
            .toSet()
            .toList();
    divisions.sort();
    return divisions;
  }

  // Get available DURP ratings
  List<String> get _availableDuprRatings {
    final ratings = <String>{};
    for (final team in widget.pickleballTeamService.teams) {
      for (final player in team.players) {
        ratings.add(player.duprRating);
      }
    }
    final ratingsList = ratings.toList();
    ratingsList.sort();
    return ratingsList;
  }

  int get _totalTeams => _basketballTeams.length + _pickleballTeams.length;

  // Get filtered teams count based on current tab
  int get _filteredTeamsCount {
    final tabIndex = _tabController.index;
    if (tabIndex == 0) {
      return _filteredBasketballTeams.length;
    } else {
      return _filteredPickleballTeams.length;
    }
  }

  // Get filtered players count based on current tab
  int get _filteredPlayersCount {
    final tabIndex = _tabController.index;
    if (tabIndex == 0) {
      return _filteredBasketballTeams.fold(
        0,
        (sum, team) => sum + team.players.length + 1,
      );
    } else {
      return _filteredPickleballTeams.fold(
        0,
        (sum, team) => sum + team.players.length + 1,
      );
    }
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

                // Show success snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Team "${updatedTeam.name}" updated successfully',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFF38A169),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 100, // Position above bottom navigation
                    ),
                    elevation: 4,
                  ),
                );
              },
              onDelete: (teamId) {
                widget.teamService.deleteTeam(teamId);
                setState(() {});

                // Show success snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Team deleted successfully',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Color(0xFF38A169),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 80, // Position above bottom navigation
                    ),
                    elevation: 4,
                  ),
                );
              },
            ),
      ),
    );
  }

  void _navigateToPickleballTeamDetail(PickleballTeam team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PickleballTeamDetailScreen(
              team: team,
              onUpdate: (updatedTeam) {
                widget.pickleballTeamService.updateTeam(updatedTeam);
                setState(() {});

                // Show success snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Team "${updatedTeam.name}" updated successfully',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFF38A169),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 100, // Position above bottom navigation
                    ),
                    elevation: 4,
                  ),
                );
              },
              onDelete: (teamId) {
                widget.pickleballTeamService.deleteTeam(teamId);
                setState(() {});

                // Show success snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Team deleted successfully',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Color(0xFF38A169),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 80, // Position above bottom navigation
                    ),
                    elevation: 4,
                  ),
                );
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 15,
                          child: Text(
                            user?.name.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                user?.name ?? 'User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 25,
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Teams',
                            '$_filteredTeamsCount',
                            Icons.sports,
                            const Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Players',
                            '$_filteredPlayersCount',
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
                    _totalTeams == 0
                        ? _buildEmptyState()
                        : Column(
                          children: [
                            // Tab Bar
                            Container(
                              color: Colors.white,
                              child: TabBar(
                                controller: _tabController,
                                labelColor: const Color(0xFF2196F3),
                                unselectedLabelColor: Colors.grey[600],
                                indicatorColor: const Color(0xFF2196F3),
                                indicatorWeight: 3,
                                tabs: const [
                                  Tab(
                                    icon: Icon(Icons.sports_basketball),
                                    text: 'Basketball',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.sports_tennis),
                                    text: 'Pickleball',
                                  ),
                                ],
                              ),
                            ),
                            // Tab Content
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildBasketballTab(),
                                  _buildPickleballTab(),
                                ],
                              ),
                            ),
                          ],
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
      padding: const EdgeInsets.all(10),
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

  // Build Basketball Tab
  Widget _buildBasketballTab() {
    return Column(
      children: [
        // Division Filter Dropdown
        if (_availableBasketballDivisions.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBasketballDivision,
                hint: const Text('Filter by Division'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Divisions'),
                  ),
                  ..._availableBasketballDivisions.map(
                    (division) => DropdownMenuItem<String>(
                      value: division,
                      child: Text(division),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBasketballDivision = value;
                  });
                },
              ),
            ),
          ),
        ],
        // Teams List
        Expanded(
          child:
              _filteredBasketballTeams.isEmpty
                  ? _buildEmptyStateForSport('Basketball')
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children:
                          _filteredBasketballTeams
                              .map(
                                (team) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildBasketballTeamCard(team),
                                ),
                              )
                              .toList(),
                    ),
                  ),
        ),
      ],
    );
  }

  // Build Pickleball Tab
  Widget _buildPickleballTab() {
    return Column(
      children: [
        // Filters Row
        if (_availablePickleballDivisions.isNotEmpty ||
            _availableDuprRatings.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Division Filter
                if (_availablePickleballDivisions.isNotEmpty) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPickleballDivision,
                          hint: const Text('Division'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Divisions'),
                            ),
                            ..._availablePickleballDivisions.map(
                              (division) => DropdownMenuItem<String>(
                                value: division,
                                child: Text(division),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPickleballDivision = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // DURP Rating Filter
                if (_availableDuprRatings.isNotEmpty) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDuprRating,
                          hint: const Text('DURP Rating'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Ratings'),
                            ),
                            ..._availableDuprRatings.map(
                              (rating) => DropdownMenuItem<String>(
                                value: rating,
                                child: Text(rating),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDuprRating = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        // Teams List
        Expanded(
          child:
              _filteredPickleballTeams.isEmpty
                  ? _buildEmptyStateForSport('Pickleball')
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children:
                          _filteredPickleballTeams
                              .map(
                                (team) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildPickleballTeamCard(team),
                                ),
                              )
                              .toList(),
                    ),
                  ),
        ),
      ],
    );
  }

  // Build empty state for specific sport
  Widget _buildEmptyStateForSport(String sport) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            sport == 'Basketball'
                ? Icons.sports_basketball
                : Icons.sports_tennis,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No $sport teams found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or register a new team',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
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

  Widget _buildBasketballTeamCard(Team team) {
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
                          'Team Captain: ${team.coachName}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
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
                    '${team.players.length + 1} Players', // +1 for captain
                    const Color(0xFF38A169),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.category,
                    team.division,
                    const Color(0xFF2196F3),
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

  Widget _buildPickleballTeamCard(PickleballTeam team) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToPickleballTeamDetail(team),
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
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sports_tennis,
                      color: Color(0xFF4CAF50),
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
                          'Team Captain: ${team.coachName}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
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
                    '${team.players.length + 1} Player${team.players.length + 1 != 1 ? 's' : ''}', // +1 for captain
                    const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.star,
                    team.division,
                    const Color(0xFF4CAF50),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
