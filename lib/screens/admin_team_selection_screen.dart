// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:io';
import '../models/team.dart';
import '../models/player.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../services/team_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_loading_widget.dart';

class AdminTeamSelectionScreen extends StatefulWidget {
  final Event event;

  const AdminTeamSelectionScreen({
    super.key,
    required this.event,
  });

  @override
  State<AdminTeamSelectionScreen> createState() => _AdminTeamSelectionScreenState();
}

class _AdminTeamSelectionScreenState extends State<AdminTeamSelectionScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Team> _allTeams = [];
  List<Team> _filteredTeams = [];
  List<Team> _registeredTeams = []; // Teams already registered for this event
  final Set<String> _selectedTeamIds = {};
  Set<String> _registeredTeamIds = {}; // IDs of teams already registered for this event
  bool _isLoading = true;
  final FocusNode _searchFocusNode = FocusNode();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Focus changed - can be used for future functionality
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    await _teamService.loadTeams();
    await _authService.initialize();
    
    // Get all teams (admins can see all teams)
    final allTeams = _teamService.teams;
    
    // Separate teams: those already registered for this event vs others
    _registeredTeams = allTeams.where((team) => team.eventId == widget.event.id).toList();
    _registeredTeamIds = _registeredTeams.map((team) => team.id).toSet();
    
    // Show teams not yet registered for this event (or all teams if filtering is disabled)
    _allTeams = allTeams.where((team) => team.eventId != widget.event.id || team.eventId.isEmpty).toList();
    
    _filteredTeams = List.from(_allTeams);
    setState(() {
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredTeams = List.from(_allTeams);
      } else {
        _filteredTeams = _allTeams.where((team) {
          return team.name.toLowerCase().contains(query) ||
                 team.coachName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _toggleTeamSelection(String teamId) {
    // Prevent selecting teams that are already registered
    if (_registeredTeamIds.contains(teamId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This team is already registered for this event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      if (_selectedTeamIds.contains(teamId)) {
        _selectedTeamIds.remove(teamId);
      } else {
        _selectedTeamIds.add(teamId);
      }
    });
  }

  // Get captain name from createdByUserId
  String _getCaptainName(Team team) {
    if (team.createdByUserId != null) {
      try {
        final user = _authService.users.firstWhere((u) => u.id == team.createdByUserId);
        return user.name;
      } catch (e) {
        // If user not found, fall back to coachName
        return team.coachName;
      }
    }
    return team.coachName;
  }

  // Build players display in columns (3 players per column)
  Widget _buildPlayersDisplay(List<Player> players) {
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate number of columns needed (3 players per column)
    final numColumns = (players.length / 3).ceil();
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(numColumns, (colIndex) {
        final startIndex = colIndex * 3;
        final endIndex = (startIndex + 3 < players.length) ? startIndex + 3 : players.length;
        final columnPlayers = players.sublist(startIndex, endIndex);
        
        return SizedBox(
          width: 120, // Fixed width for each column
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnPlayers.map((player) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  player.userId != null 
                      ? '${player.name} (${player.userId!})' // Show full ID for registered users
                      : '${player.name} (Guest)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }),
    );
  }

  void _registerSelectedTeams() async {
    if (_selectedTeamIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one team'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get selected teams
    final selectedTeams = _allTeams.where((team) => _selectedTeamIds.contains(team.id)).toList();
    
    // Filter out teams that are already registered
    final teamsToRegister = selectedTeams.where((team) => !_registeredTeamIds.contains(team.id)).toList();
    
    if (teamsToRegister.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected teams are already registered for this event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Register each team for the event
    for (final team in teamsToRegister) {
      // Check if team is already registered for this event
      if (_registeredTeamIds.contains(team.id)) {
        continue; // Skip if already registered
      }
      
      // Update team with event ID
      final updatedTeam = Team(
        id: team.id,
        name: team.name,
        coachName: team.coachName,
        coachPhone: team.coachPhone,
        coachEmail: team.coachEmail,
        coachAge: team.coachAge,
        players: team.players,
        registrationDate: team.registrationDate,
        division: team.division,
        createdByUserId: team.createdByUserId,
        isPrivate: team.isPrivate,
        eventId: widget.event.id, // Link to event
      );
      
      // Save updated team
      await _teamService.updateTeam(updatedTeam);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${teamsToRegister.length} team(s) registered successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Reload teams to update registered teams list
      await _loadTeams();
      setState(() {
        _selectedTeamIds.clear(); // Clear selection after registration
      });
    }
  }

  void _createNewTeam() {
    final teamNameController = TextEditingController();
    final playerSearchController = TextEditingController();
    final authService = AuthService();
    List<Player> selectedPlayers = [];
    List<User> searchResults = [];
    bool isSearching = false;
    
    void performSearch(String query) {
      if (query.isEmpty) {
        searchResults = [];
        isSearching = false;
      } else {
        final lowerQuery = query.toLowerCase();
        searchResults = authService.users.where((user) {
          return user.name.toLowerCase().contains(lowerQuery) ||
                 user.username.toLowerCase().contains(lowerQuery) ||
                 user.email.toLowerCase().contains(lowerQuery);
        }).toList();
        isSearching = true;
      }
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Team'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Team Name
                  TextField(
                    controller: teamNameController,
                    decoration: const InputDecoration(
                      labelText: 'Team Name',
                      hintText: 'Enter team name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),
                  
                  // Add Players Section
                  const Text(
                    'Add Players',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Player Search Field
                  TextField(
                    controller: playerSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search Player',
                      hintText: 'Enter player name, username, or email',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: playerSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                playerSearchController.clear();
                                setDialogState(() {
                                  searchResults = [];
                                  isSearching = false;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        performSearch(value);
                      });
                    },
                  ),
                  
                  // Search Results
                  if (isSearching && searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          final isAlreadyAdded = selectedPlayers.any((p) => p.userId == user.id);
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.profilePicturePath != null
                                  ? FileImage(File(user.profilePicturePath!))
                                  : null,
                              child: user.profilePicturePath == null
                                  ? Text(user.name[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(user.name),
                            subtitle: isAlreadyAdded
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('@${user.username}'),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Player already registered',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text('@${user.username}'),
                            trailing: isAlreadyAdded
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.add),
                            onTap: isAlreadyAdded
                                ? () {
                                    // Show message that player is already registered
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('This player is already registered'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : () {
                                    final player = Player(
                                      id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
                                      name: user.name,
                                      position: 'Player',
                                      jerseyNumber: int.tryParse(user.jerseyNumber ?? '0') ?? 0,
                                      phoneNumber: user.phone,
                                      email: user.email,
                                      age: user.age ?? 0,
                                      height: double.tryParse(user.height ?? '0') ?? 0.0,
                                      weight: double.tryParse(user.weight ?? '0') ?? 0.0,
                                      userId: user.id, // Link to user profile
                                    );
                                    setDialogState(() {
                                      selectedPlayers.add(player);
                                      playerSearchController.clear();
                                      searchResults = [];
                                      isSearching = false;
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                  
                  // Always show "Add as Guest Player" option when there's text in search field
                  if (playerSearchController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.blue[50],
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.person_add, color: Colors.blue),
                        title: Text('Add "${playerSearchController.text}" as Guest Player'),
                        trailing: const Icon(Icons.arrow_forward, color: Colors.blue),
                        onTap: () {
                          // Directly add guest player with searched name
                          final guestName = playerSearchController.text.trim();
                          if (guestName.isEmpty) {
                            return;
                          }
                          
                          // Check if already added as guest
                          final alreadyAdded = selectedPlayers.any(
                            (p) => p.userId == null && p.name.toLowerCase() == guestName.toLowerCase(),
                          );
                          
                          if (alreadyAdded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This guest player is already added'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          
                          final guestPlayer = Player(
                            id: '${DateTime.now().millisecondsSinceEpoch}guest',
                            name: guestName,
                            position: 'Player',
                            jerseyNumber: 0,
                            phoneNumber: '',
                            email: '',
                            age: 0,
                            height: 0.0,
                            weight: 0.0,
                            userId: null, // Guest player
                          );
                          
                          setDialogState(() {
                            selectedPlayers.add(guestPlayer);
                            playerSearchController.clear();
                            searchResults = [];
                            isSearching = false;
                          });
                        },
                      ),
                    ),
                  ],
                  
                  // Selected Players List
                  if (selectedPlayers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Selected Players:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...selectedPlayers.map((player) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(player.name[0].toUpperCase()),
                          ),
                          title: Text(player.name),
                          subtitle: Text(player.userId != null ? 'Registered User' : 'Guest'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                selectedPlayers.remove(player);
                              });
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                teamNameController.dispose();
                playerSearchController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final teamName = teamNameController.text.trim();
                if (teamName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a team name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Get current user (admin/owner creating the team)
                final currentUser = authService.currentUser;
                
                // Create team with players
                final newTeam = Team(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: teamName,
                  coachName: currentUser?.name ?? 'TBD', // Set captain as the creator
                  coachPhone: currentUser?.phone ?? '',
                  coachEmail: currentUser?.email ?? '',
                  coachAge: currentUser?.age ?? 25,
                  players: selectedPlayers,
                  registrationDate: DateTime.now(),
                  division: widget.event.division ?? 'Adult 18+',
                  createdByUserId: currentUser?.id, // Set creator as the admin/owner
                  isPrivate: false,
                  eventId: widget.event.id, // Register for the event immediately
                );
                
                // Save the team
                await _teamService.addTeam(newTeam);
                
                if (mounted) {
                  teamNameController.dispose();
                  playerSearchController.dispose();
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Team "$teamName" created with ${selectedPlayers.length} player(s) and registered successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Reload teams list to show the new team
                  _loadTeams();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Team'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.event.title} - Team Registration',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2196F3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  labelText: 'Enter Team Name',
                  hintText: 'Search teams...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _onSearchChanged(),
              ),
            ),
            
            // Teams list
            Expanded(
              child: _isLoading
                  ? const Center(child: AppLoadingWidget())
                  : _filteredTeams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'No teams registered yet'
                                    : 'No teams found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTeams.length,
                          itemBuilder: (context, index) {
                            final team = _filteredTeams[index];
                            final isSelected = _selectedTeamIds.contains(team.id);
                            
                            final captainName = _getCaptainName(team);
                            final isAlreadyRegistered = _registeredTeamIds.contains(team.id);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 4 : 1,
                              color: isAlreadyRegistered 
                                  ? Colors.grey[200] 
                                  : (isSelected ? Colors.blue[50] : null),
                              child: CheckboxListTile(
                                title: Text(
                                  team.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isAlreadyRegistered ? Colors.grey[600] : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Captain: $captainName',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (team.players.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildPlayersDisplay(team.players),
                                    ],
                                  ],
                                ),
                                value: isSelected,
                                onChanged: isAlreadyRegistered 
                                    ? null 
                                    : (_) => _toggleTeamSelection(team.id),
                                secondary: CircleAvatar(
                                  backgroundColor: isAlreadyRegistered 
                                      ? Colors.grey[400] 
                                      : const Color(0xFF2196F3),
                                  child: Text(
                                    team.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            // Teams Registered Already section (at the bottom)
            if (_registeredTeams.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teams Registered Already',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150, // Fixed height for scrollable list
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _registeredTeams.length,
                        itemBuilder: (context, index) {
                          final team = _registeredTeams[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              child: Text(team.name[0].toUpperCase()),
                            ),
                            title: Text(
                              team.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Captain: ${_getCaptainName(team)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
            
            // Make New Team button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createNewTeam,
                      icon: const Icon(Icons.add),
                      label: const Text('Make New Team'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  
                  // Register Selected Teams button
                  if (_selectedTeamIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _registerSelectedTeams,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Register ${_selectedTeamIds.length} Selected Team(s)',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

