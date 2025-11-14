// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import '../services/social_service.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../widgets/app_loading_widget.dart';

class PlayerStatsScreen extends StatefulWidget {
  final User? user; // If null, show current user's stats

  const PlayerStatsScreen({super.key, this.user});

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _eventService = EventService();
  final _teamService = TeamService();
  final _pickleballTeamService = PickleballTeamService();
  final _socialService = SocialService();
  
  User? _displayUser;
  List<Event> _events = [];
  List<Team> _teams = [];
  List<PickleballTeam> _pickleballTeams = [];
  Map<String, dynamic>? _lastMatch;
  Map<String, dynamic>? _nextMatch;
  List<User> _followers = [];
  List<User> _following = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isViewingOwnProfile = false;
  bool _isPanelOpen = false;
  bool _isLoading = true;
  TabController? _panelTabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
    _loadData();
  }

  void _initTabController() {
    _panelTabController?.dispose();
    _panelTabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _panelTabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await _eventService.initialize();
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    
    setState(() {
      _displayUser = widget.user ?? _authService.currentUser;
      final currentUser = _authService.currentUser;
      _isViewingOwnProfile = _displayUser?.id == currentUser?.id;
      _events = _eventService.events;
      _teams = _teamService.teams;
      _pickleballTeams = _pickleballTeamService.teams;
    });

    _loadMatches();
    await _loadSocialData();
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSocialData() async {
    if (_displayUser == null) return;

    final followersIds = await _socialService.getFollowers(_displayUser!.id);
    final followingIds = await _socialService.getFollowing(_displayUser!.id);
    
    _followers = await _socialService.getUsersFromIds(followersIds);
    _following = await _socialService.getUsersFromIds(followingIds);
    
    if (!_isViewingOwnProfile && _authService.currentUser != null) {
      _isFollowing = await _socialService.isFollowing(_displayUser!.id);
    }

    setState(() {
      _followersCount = _followers.length;
      _followingCount = _following.length;
    });
  }

  void _loadMatches() {
    if (_displayUser == null) return;

    // Find user's teams (created by user OR user is a player OR user is captain)
    final userTeams = <dynamic>[];
    
    // Regular teams: check if user created it, is a player, or is the captain
    for (var team in _teams) {
      final isCreator = team.createdByUserId == _displayUser!.id;
      final isCaptain = team.coachEmail.toLowerCase() == _displayUser!.email.toLowerCase() ||
                       team.coachName.toLowerCase() == _displayUser!.name.toLowerCase();
      final isPlayer = team.players.any((p) => p.userId == _displayUser!.id);
      
      if (isCreator || isCaptain || isPlayer) {
        userTeams.add(team);
      }
    }
    
    // Pickleball teams: check if user created it, is a player, or is the captain
    for (var team in _pickleballTeams) {
      final isCreator = team.createdByUserId == _displayUser!.id;
      final isCaptain = team.coachEmail.toLowerCase() == _displayUser!.email.toLowerCase() ||
                       team.coachName.toLowerCase() == _displayUser!.name.toLowerCase();
      // PickleballPlayer doesn't have userId, check by name match instead
      final isPlayer = team.players.any((p) => p.name.toLowerCase() == _displayUser!.name.toLowerCase());
      
      if (isCreator || isCaptain || isPlayer) {
        userTeams.add(team);
      }
    }

    // Find last completed match
    final now = DateTime.now();
    Map<String, dynamic>? lastMatch;
    DateTime? lastMatchDate;

    for (var team in userTeams) {
      final event = _events.firstWhere(
        (e) => e.id == team.eventId,
        orElse: () => _events.first,
      );

      // Check if event is completed (using date as end date for now)
      if (event.date.isBefore(now)) {
        final matchDate = event.date;
        if (lastMatchDate == null || matchDate.isAfter(lastMatchDate)) {
          lastMatchDate = matchDate;
          lastMatch = {
            'opponent': 'Opponent Team', // You'll need to implement opponent logic
            'sport': event.sportName,
            'score': 'Final Score', // You'll need to get actual score
            'won': true, // You'll need to determine win/loss
            'date': matchDate,
          };
        }
      }
    }

    // Find next upcoming match
    Map<String, dynamic>? nextMatch;
    DateTime? nextMatchDate;

    for (var team in userTeams) {
      final event = _events.firstWhere(
        (e) => e.id == team.eventId,
        orElse: () => _events.first,
      );

      if (event.date.isAfter(now)) {
        final matchDate = event.date;
        if (nextMatchDate == null || matchDate.isBefore(nextMatchDate)) {
          nextMatchDate = matchDate;
          nextMatch = {
            'sport': event.sportName,
            'date': matchDate,
          };
        }
      }
    }

    setState(() {
      _lastMatch = lastMatch;
      _nextMatch = nextMatch;
    });
  }


  Future<void> _toggleFollow() async {
    if (_displayUser == null || _isViewingOwnProfile) return;

    setState(() {
      _isFollowing = !_isFollowing;
    });

    final success = _isFollowing
        ? await _socialService.followUser(_displayUser!.id)
        : await _socialService.unfollowUser(_displayUser!.id);

    if (!success) {
      setState(() {
        _isFollowing = !_isFollowing;
      });
    } else {
      await _loadSocialData();
    }
  }

  void _openMessageScreen() {
    // Placeholder for messaging functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Messaging feature coming soon'),
        backgroundColor: Color(0xFF2196F3),
      ),
    );
  }


  String _getFirstName(String fullName) {
    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }

  String _getLastName(String fullName) {
    final parts = fullName.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _displayUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: const Center(
            child: AppLoadingWidget(size: 120),
          ),
        ),
      );
    }

    final fullName = _displayUser!.name;
    final lastName = _getLastName(fullName);

    return PopScope(
      canPop: !_isPanelOpen,
      onPopInvoked: (didPop) {
        if (!didPop && _isPanelOpen) {
          setState(() => _isPanelOpen = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Stack(
            children: [
              // Main content - disable interaction when panel is open
              AbsorbPointer(
                absorbing: _isPanelOpen,
                child: Opacity(
                  opacity: _isPanelOpen ? 0.3 : 1.0,
                  child: Column(
                  children: [
                    // Back Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              if (_isPanelOpen) {
                                setState(() => _isPanelOpen = false);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header (shown for all users)
                        _buildProfileHeader(),
                        const SizedBox(height: 32),
                        
                        // Header Section (includes Height, Weight, Age)
                        _buildHeader(fullName, lastName.isNotEmpty ? lastName : fullName.split(' ').first),
                        
                        const SizedBox(height: 32),
                        
                        // Match Display Section
                        _buildMatchSection(),
                      ],
                    ),
                  ),
                ),
              ],
                    ),
                  ),
                ),
            
            // Faded background overlay when panel is open
            if (_isPanelOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isPanelOpen = false);
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
            
            // Right Side Panel - Following/Followers
            if (_isPanelOpen)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from propagating to main content
                  child: Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      border: Border(
                        left: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header with tabs and close button - at the top
                        Container(
                          padding: const EdgeInsets.only(top: 12, left: 12, right: 8, bottom: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // TabBar at the top - takes available space
                              Expanded(
                                child: _panelTabController != null
                                    ? TabBar(
                                        controller: _panelTabController!,
                                        labelColor: Colors.white,
                                        unselectedLabelColor: Colors.grey[400],
                                        indicatorColor: const Color(0xFF2196F3),
                                        labelStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        unselectedLabelStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                        tabs: const [
                                          Tab(text: 'Following'),
                                          Tab(text: 'Followers'),
                                        ],
                                      )
                                    : const SizedBox(),
                              ),
                              // Close button next to tabs
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() => _isPanelOpen = false);
                                },
                              ),
                            ],
                          ),
                        ),
                        // Tab content
                        Expanded(
                          child: _panelTabController != null
                              ? TabBarView(
                                  controller: _panelTabController!,
                                  children: [
                                    _buildUserList(_following, 'No Following'),
                                    _buildUserList(_followers, 'No Followers'),
                                  ],
                                )
                              : const Center(
                                  child: AppLoadingWidget(size: 60),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List<User> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2196F3),
                  backgroundImage: user.profilePicturePath != null &&
                          File(user.profilePicturePath!).existsSync()
                      ? FileImage(File(user.profilePicturePath!))
                      : null,
                  child: user.profilePicturePath == null ||
                          !File(user.profilePicturePath!).existsSync()
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  setState(() => _isPanelOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerStatsScreen(user: user),
                    ),
                  );
                },
              );
            },
          );
  }

  Widget _buildProfileHeader() {
    if (_displayUser == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF2196F3),
            backgroundImage: _displayUser!.profilePicturePath != null &&
                    File(_displayUser!.profilePicturePath!).existsSync()
                ? FileImage(File(_displayUser!.profilePicturePath!))
                : null,
            child: _displayUser!.profilePicturePath == null ||
                    !File(_displayUser!.profilePicturePath!).existsSync()
                ? Text(
                    _displayUser!.name.isNotEmpty
                        ? _displayUser!.name.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // Name and Username Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                Text(
                  _displayUser!.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // Username
                Text(
                  '@${_displayUser!.username}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Following/Followers Row
                Opacity(
                  opacity: _isPanelOpen ? 0.5 : 1.0,
                  child: Row(
                    children: [
                      // Following
                      GestureDetector(
                        onTap: _isPanelOpen
                            ? null
                            : () {
                                if (_panelTabController != null) {
                                  _panelTabController!.animateTo(0);
                                }
                                setState(() => _isPanelOpen = true);
                              },
                        child: Row(
                          children: [
                            Text(
                              _followingCount.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isPanelOpen ? Colors.grey[600] : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Following',
                              style: TextStyle(
                                fontSize: 14,
                                color: _isPanelOpen ? Colors.grey[600] : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Followers
                      GestureDetector(
                        onTap: _isPanelOpen
                            ? null
                            : () {
                                if (_panelTabController != null) {
                                  _panelTabController!.animateTo(1);
                                }
                                setState(() => _isPanelOpen = true);
                              },
                        child: Row(
                          children: [
                            Text(
                              _followersCount.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isPanelOpen ? Colors.grey[600] : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Followers',
                              style: TextStyle(
                                fontSize: 14,
                                color: _isPanelOpen ? Colors.grey[600] : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Buttons (only when not viewing own profile)
          if (!_isViewingOwnProfile) ...[
            const SizedBox(width: 12),
            Column(
              children: [
                // Follow/Following Button
                ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFollowing
                        ? Colors.grey[700]
                        : const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Message Button
                ElevatedButton(
                  onPressed: _openMessageScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF252525),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[700]!, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String fullName, String lastNameForBackground) {
    final firstName = _getFirstName(fullName);
    final lastName = _getLastName(fullName);
    final displayLastName = lastName.isNotEmpty ? lastName : firstName;
    
    return Stack(
      children: [
        // Faded background last name - full width
        Positioned.fill(
          child: Opacity(
            opacity: 0.1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  displayLastName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 150,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        ),
        
        // Main header content
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Player Number and Height/Weight/Age Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Name section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Player Number
                        if (_displayUser!.jerseyNumber != null)
                          Text(
                            '#${_displayUser!.jerseyNumber}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        
                        const SizedBox(height: 8),
                        
                        // First Name (small)
                        Text(
                          firstName,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Last Name (large bold)
                        Text(
                          displayLastName,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Right side: Height, Weight, Age
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildCompactInfoItem('Height', _displayUser!.height ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildCompactInfoItem('Weight', _displayUser!.weight ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildCompactInfoItem('Age', _displayUser!.age?.toString() ?? 'N/A'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInfoItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[400],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSection() {
    return Row(
      children: [
        // Last Match Button
        Expanded(
          child: _buildMatchButton('Last Match', _lastMatch, isLast: true),
        ),
        
        const SizedBox(width: 16),
        
        // Next Match Button
        Expanded(
          child: _buildMatchButton('Next Match', _nextMatch, isLast: false),
        ),
      ],
    );
  }

  Widget _buildMatchButton(String title, Map<String, dynamic>? match, {required bool isLast}) {
    String formatDate(DateTime date) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    
    return GestureDetector(
      onTap: () {
        // Close panel if open before opening dialog
        if (_isPanelOpen) {
          setState(() => _isPanelOpen = false);
          return;
        }
        _showMatchDialog(title, match, isLast);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: match == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sport name
                  if (match['sport'] != null)
                    Text(
                      match['sport'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Date
                  if (match['date'] != null)
                    Text(
                      formatDate(match['date'] as DateTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                      ),
                    ),
                  // Last Match: Also show opponent and score
                  if (isLast) ...[
                    const SizedBox(height: 8),
                    if (match['opponent'] != null)
                      Text(
                        'vs ${match['opponent']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    if (match['score'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Score: ${match['score']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }

  void _showMatchDialog(String title, Map<String, dynamic>? match, bool isLast) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF252525),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title and Okay button row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centered title
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Okay button on the right
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.check, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Okay',
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.grey, height: 1),
              
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: match == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'N/A',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Opponent
                            Text(
                              match['opponent'] ?? 'Opponent',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Sport
                            Text(
                              'Sport: ${match['sport'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            
                            if (isLast && match['won'] != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: match['won'] == true ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  match['won'] == true ? 'WIN' : 'LOSE',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            
                            if (isLast && match['score'] != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Score: ${match['score']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                            
                            if (match['date'] != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Date: ${match['date']}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



}

