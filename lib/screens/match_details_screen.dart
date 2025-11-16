// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';

class MatchDetailsScreen extends StatefulWidget {
  final User? user; // If null, show current user's matches
  final bool isLastMatch; // true for Last Match, false for Next Match

  const MatchDetailsScreen({
    super.key,
    this.user,
    required this.isLastMatch,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  final _authService = AuthService();
  final _eventService = EventService();
  final _teamService = TeamService();
  final _pickleballTeamService = PickleballTeamService();
  
  User? _displayUser;
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
    });

    await _eventService.initialize();
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    
    _displayUser = widget.user ?? _authService.currentUser;
    if (_displayUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Find user's teams
    final userTeams = <dynamic>[];
    
    // Regular teams
    for (var team in _teamService.teams) {
      final isCreator = team.createdByUserId == _displayUser!.id;
      final isCaptain = team.coachEmail.toLowerCase() == _displayUser!.email.toLowerCase() ||
                       team.coachName.toLowerCase() == _displayUser!.name.toLowerCase();
      final isPlayer = team.players.any((p) => p.userId == _displayUser!.id);
      
      if (isCreator || isCaptain || isPlayer) {
        userTeams.add(team);
      }
    }
    
    // Pickleball teams
    for (var team in _pickleballTeamService.teams) {
      final isCreator = team.createdByUserId == _displayUser!.id;
      final isCaptain = team.coachEmail.toLowerCase() == _displayUser!.email.toLowerCase() ||
                       team.coachName.toLowerCase() == _displayUser!.name.toLowerCase();
      final isPlayer = team.players.any((p) => p.name.toLowerCase() == _displayUser!.name.toLowerCase());
      
      if (isCreator || isCaptain || isPlayer) {
        userTeams.add(team);
      }
    }

    // Get all matches for user's teams
    final now = DateTime.now();
    final allMatches = <Map<String, dynamic>>[];

    for (var team in userTeams) {
      final event = _eventService.events.firstWhere(
        (e) => e.id == team.eventId,
        orElse: () => _eventService.events.first,
      );

      // Filter by date based on isLastMatch
      final isPastMatch = event.date.isBefore(now);
      if (widget.isLastMatch && !isPastMatch) continue;
      if (!widget.isLastMatch && isPastMatch) continue;

      // Try to get match scores from ScoreService
      // For now, we'll use event data and team info
      final opponentTeam = _findOpponentTeam(team, event);
      
      // Determine win/loss (simplified - you may need to enhance this based on actual score data)
      final won = _determineWinLoss(team, opponentTeam, event);
      final score = _getScore(team, opponentTeam, event);

      allMatches.add({
        'sport': event.sportName,
        'date': event.date,
        'teamName': team.name,
        'opponentTeam': opponentTeam?.name ?? 'TBD',
        'won': won,
        'score': score,
        'event': event,
        'team': team,
      });
    }

    // Sort matches by date (most recent first for last matches, earliest first for next matches)
    allMatches.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return widget.isLastMatch 
          ? dateB.compareTo(dateA) // Most recent first
          : dateA.compareTo(dateB); // Earliest first
    });

    setState(() {
      _matches = allMatches;
      _isLoading = false;
    });
  }

  dynamic _findOpponentTeam(dynamic userTeam, Event event) {
    // Find other teams in the same event
    final eventTeams = <dynamic>[];
    
    // Regular teams in event
    for (var team in _teamService.teams) {
      if (team.eventId == event.id && team.id != userTeam.id) {
        eventTeams.add(team);
      }
    }
    
    // Pickleball teams in event
    for (var team in _pickleballTeamService.teams) {
      if (team.eventId == event.id && team.id != userTeam.id) {
        eventTeams.add(team);
      }
    }

    // Return first opponent team (in a real scenario, you'd match based on actual match schedule)
    return eventTeams.isNotEmpty ? eventTeams.first : null;
  }

  bool? _determineWinLoss(dynamic userTeam, dynamic opponentTeam, Event event) {
    // This is simplified - in reality, you'd check actual match scores
    // For now, return null (unknown) or you could implement logic based on event completion
    if (opponentTeam == null) return null;
    
    // Try to get score from ScoreService if available
    // For now, return null (unknown result)
    return null;
  }

  String _getScore(dynamic userTeam, dynamic opponentTeam, Event event) {
    // Try to get actual score from ScoreService
    // For now, return a placeholder
    if (opponentTeam == null) return 'TBD';
    
    // In a real implementation, you'd query ScoreService for match scores
    // For now, return a sample score format
    return '11-5'; // Placeholder
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252525),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isLastMatch ? 'Last Matches' : 'Next Matches',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            )
          : _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${widget.isLastMatch ? 'past' : 'upcoming'} matches',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    return _buildMatchTile(_matches[index]);
                  },
                ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match) {
    final sport = match['sport'] as String;
    final date = match['date'] as DateTime;
    final teamName = match['teamName'] as String;
    final opponentTeam = match['opponentTeam'] as String;
    final won = match['won'] as bool?;
    final score = match['score'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sport and Date Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sport
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSportIcon(sport),
                        size: 16,
                        color: const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sport,
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Date
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Score
            Row(
              children: [
                Text(
                  'Score: ',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                Text(
                  score,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Team vs Opponent
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Team',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teamName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'vs',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Opponent',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opponentTeam,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // WIN/LOSS badge (only for last matches)
            if (widget.isLastMatch && won != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: won ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: won ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        won ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: won ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        won ? 'WIN' : 'LOSS',
                        style: TextStyle(
                          color: won ? Colors.green : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    final lowerSport = sport.toLowerCase();
    if (lowerSport.contains('pickleball') || lowerSport.contains('pickelball')) {
      return Icons.sports_tennis;
    } else if (lowerSport.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lowerSport.contains('volleyball')) {
      return Icons.sports_volleyball;
    } else if (lowerSport.contains('soccer')) {
      return Icons.sports_soccer;
    }
    return Icons.sports;
  }
}


