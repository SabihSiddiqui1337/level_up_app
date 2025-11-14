// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:io';
import '../models/team.dart';
import '../models/player.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../services/team_service.dart';
import '../services/auth_service.dart';

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
  Set<String> _selectedTeamIds = {};
  bool _isLoading = true;
  bool _showTeamsList = false; // Show teams when field is tapped
  final FocusNode _searchFocusNode = FocusNode();

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
    setState(() {
      _showTeamsList = _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;
    });
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    await _teamService.loadTeams();
    
    // Get all teams (admins can see all teams)
    // Show ALL registered teams, even if they're registered for other events
    final allTeams = _teamService.teams;
    _allTeams = List.from(allTeams); // Show all teams
    
    _filteredTeams = List.from(_allTeams);
    setState(() => _isLoading = false);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _showTeamsList = _searchFocusNode.hasFocus || query.isNotEmpty;
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
    setState(() {
      if (_selectedTeamIds.contains(teamId)) {
        _selectedTeamIds.remove(teamId);
      } else {
        _selectedTeamIds.add(teamId);
      }
    });
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
    
    // Register each team for the event
    for (final team in selectedTeams) {
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
      _teamService.updateTeam(updatedTeam);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedTeams.length} team(s) registered successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
                            subtitle: Text('@${user.username}'),
                            trailing: isAlreadyAdded
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.add),
                            onTap: isAlreadyAdded
                                ? null
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
                            id: DateTime.now().millisecondsSinceEpoch.toString() + 'guest',
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
                
                // Create team with players
                final newTeam = Team(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: teamName,
                  coachName: 'TBD', // To be determined
                  coachPhone: '',
                  coachEmail: '',
                  coachAge: 0,
                  players: selectedPlayers,
                  registrationDate: DateTime.now(),
                  division: widget.event.division ?? 'Adult 18+',
                  createdByUserId: null,
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
                  hintText: 'Tap to see all teams or search...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _showTeamsList = _searchFocusNode.hasFocus;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _onSearchChanged(),
                onTap: () {
                  setState(() {
                    _showTeamsList = true;
                  });
                },
              ),
            ),
            
            // Teams list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !_showTeamsList
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Tap on "Enter Team Name" to see all teams',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
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
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 4 : 1,
                              color: isSelected ? Colors.blue[50] : null,
                              child: CheckboxListTile(
                                title: Text(
                                  team.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Captain: ${team.coachName}'),
                                    Text('Players: ${team.players.length}'),
                                    if (team.division.isNotEmpty)
                                      Text('Division: ${team.division}'),
                                  ],
                                ),
                                value: isSelected,
                                onChanged: (_) => _toggleTeamSelection(team.id),
                                secondary: CircleAvatar(
                                  child: Text(team.name[0].toUpperCase()),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
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

