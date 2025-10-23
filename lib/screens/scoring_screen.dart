import 'package:flutter/material.dart';
import '../widgets/simple_app_bar.dart';
import '../models/match.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';

class ScoringScreen extends StatefulWidget {
  final String sportName;
  final TeamService? teamService;
  final PickleballTeamService? pickleballTeamService;

  const ScoringScreen({
    super.key,
    required this.sportName,
    this.teamService,
    this.pickleballTeamService,
  });

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  List<Match> _matches = [];
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

    try {
      // Load matches based on sport type
      if (widget.sportName.toLowerCase().contains('basketball')) {
        await widget.teamService?.loadTeams();
        _matches = _generateMatches(widget.teamService?.teams ?? []);
      } else if (widget.sportName.toLowerCase().contains('pickleball')) {
        await widget.pickleballTeamService?.loadTeams();
        _matches = _generateMatches(widget.pickleballTeamService?.teams ?? []);
      }
    } catch (e) {
      print('Error loading matches: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Match> _generateMatches(List<dynamic> teams) {
    List<Match> matches = [];

    if (teams.length < 2) {
      return matches;
    }

    // Generate matches for each team to play 3 games
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        if (matches.length < teams.length * 3) {
          matches.add(
            Match(
              id: 'match_${i}_${j}_${DateTime.now().millisecondsSinceEpoch}',
              day: 'Day ${matches.length + 1}',
              court: 'Court ${(matches.length % 3) + 1}',
              time: '${9 + (matches.length % 8)}:00 AM',
              team1: teams[i].name,
              team2: teams[j].name,
              team1Status: 'Not Checked-in',
              team2Status: 'Not Checked-in',
              team1Score: 0,
              team2Score: 0,
              team1Id: teams[i].id,
              team2Id: teams[j].id,
              team1Name: teams[i].name,
              team2Name: teams[j].name,
              isCompleted: false,
              scheduledDate: DateTime.now().add(Duration(days: matches.length)),
            ),
          );
        }
      }
    }

    return matches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(
        title: '${widget.sportName} Scoring',
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _matches.isEmpty
                ? _buildEmptyState()
                : _buildMatchesList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No matches to score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Matches will appear here when teams are registered',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        return _buildMatchCard(match);
      },
    );
  }

  Widget _buildMatchCard(Match match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports,
                  color: match.isCompleted ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Match ${_matches.indexOf(match) + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: match.isCompleted ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    match.isCompleted ? 'Completed' : 'Pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTeamScore(
                    match.team1Name ?? match.team1,
                    match.team1Score,
                    match.isCompleted,
                    (score) => _updateScore(match, score, null),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTeamScore(
                    match.team2Name ?? match.team2,
                    match.team2Score,
                    match.isCompleted,
                    (score) => _updateScore(match, null, score),
                  ),
                ),
              ],
            ),
            if (!match.isCompleted) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeMatch(match),
                      icon: const Icon(Icons.check),
                      label: const Text('Complete Match'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScore(
    String teamName,
    int score,
    bool isCompleted,
    Function(int) onScoreChanged,
  ) {
    return Column(
      children: [
        Text(
          teamName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: isCompleted ? null : () => onScoreChanged(score - 1),
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                score.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: isCompleted ? null : () => onScoreChanged(score + 1),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateScore(Match match, int? team1Score, int? team2Score) {
    setState(() {
      final index = _matches.indexOf(match);
      _matches[index] = Match(
        id: match.id,
        day: match.day,
        court: match.court,
        time: match.time,
        team1: match.team1,
        team2: match.team2,
        team1Status: match.team1Status,
        team2Status: match.team2Status,
        team1Score: team1Score ?? match.team1Score,
        team2Score: team2Score ?? match.team2Score,
        team1Id: match.team1Id,
        team2Id: match.team2Id,
        team1Name: match.team1Name,
        team2Name: match.team2Name,
        isCompleted: match.isCompleted,
        scheduledDate: match.scheduledDate,
      );
    });
  }

  void _completeMatch(Match match) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Complete Match'),
            content: Text(
              'Are you sure you want to complete this match?\n\n'
              '${match.team1Name}: ${match.team1Score}\n'
              '${match.team2Name}: ${match.team2Score}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final index = _matches.indexOf(match);
                    _matches[index] = Match(
                      id: match.id,
                      day: match.day,
                      court: match.court,
                      time: match.time,
                      team1: match.team1,
                      team2: match.team2,
                      team1Status: match.team1Status,
                      team2Status: match.team2Status,
                      team1Score: match.team1Score,
                      team2Score: match.team2Score,
                      team1Id: match.team1Id,
                      team2Id: match.team2Id,
                      team1Name: match.team1Name,
                      team2Name: match.team2Name,
                      isCompleted: true,
                      scheduledDate: match.scheduledDate,
                    );
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Match completed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Complete'),
              ),
            ],
          ),
    );
  }
}
