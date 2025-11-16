import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/match.dart';
import '../services/score_service.dart';

class CustomScheduleScreen extends StatefulWidget {
  final List<dynamic> allTeams;
  final String division;
  final String sportName;
  final int selectedGames;
  final int selectedScore;
  final Function(List<Match>) onScheduleCreated;

  const CustomScheduleScreen({
    super.key,
    required this.allTeams,
    required this.division,
    required this.sportName,
    required this.selectedGames,
    required this.selectedScore,
    required this.onScheduleCreated,
  });

  @override
  State<CustomScheduleScreen> createState() => _CustomScheduleScreenState();
}

class _CustomScheduleScreenState extends State<CustomScheduleScreen> {
  final ScoreService _scoreService = ScoreService();
  List<Map<String, dynamic>> matchups = [];
  String? selectedTeam1;
  String? selectedTeam2;

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Unlock orientation when disposing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  List<dynamic> get _unassignedTeams {
    final usedTeamIds = <String>{};
    for (var matchup in matchups) {
      usedTeamIds.add(matchup['team1'].id);
      usedTeamIds.add(matchup['team2'].id);
    }
    return widget.allTeams.where((team) => !usedTeamIds.contains(team.id)).toList();
  }

  bool get _allTeamsAssigned {
    return _unassignedTeams.isEmpty && matchups.isNotEmpty;
  }

  void _addMatchup() {
    if (selectedTeam1 != null && selectedTeam2 != null && selectedTeam1 != selectedTeam2) {
      final team1 = widget.allTeams.firstWhere((t) => t.id == selectedTeam1);
      final team2 = widget.allTeams.firstWhere((t) => t.id == selectedTeam2);

      setState(() {
        matchups.add({
          'team1': team1,
          'team2': team2,
        });
        selectedTeam1 = null;
        selectedTeam2 = null;
      });
    }
  }

  void _removeMatchup(int index) {
    setState(() {
      matchups.removeAt(index);
    });
  }

  Future<void> _createSchedule() async {
    if (!_allTeamsAssigned) return;

    List<Match> customMatches = [];
    int matchId = 1;
    int courtNumber = 1;
    int timeSlot = 10;

    for (var matchup in matchups) {
      final team1 = matchup['team1'];
      final team2 = matchup['team2'];
      final divisionMatchId = '${widget.division}_$matchId';

      customMatches.add(
        Match(
          id: divisionMatchId,
          day: 'Day 1',
          court: 'Court $courtNumber',
          time: '$timeSlot:00',
          team1: team1.name,
          team2: team2.name,
          team1Status: 'Not Checked-in',
          team2Status: 'Not Checked-in',
          team1Score: 0,
          team2Score: 0,
          team1Id: team1.id,
          team2Id: team2.id,
        ),
      );

      matchId++;
      courtNumber++;
      if (courtNumber > 4) {
        courtNumber = 1;
        timeSlot++;
      }
    }

    // Save custom schedule flag
    await _scoreService.saveCustomScheduleForDivision(widget.division, true);

    // Return matches to parent
    widget.onScheduleCreated(customMatches);

    // Unlock orientation before navigating back
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext cancelContext) {
        return AlertDialog(
          title: const Text('Cancel Custom Schedule?'),
          content: const Text('Are you sure you want to cancel creating a custom schedule?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(cancelContext).pop(false),
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(cancelContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('YES'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      // Clear custom schedule flag
      await _scoreService.saveCustomScheduleForDivision(widget.division, false);

      // Unlock orientation and set back to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      if (mounted) {
        // Navigate back to home screen (MainNavigationScreen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unassignedTeams = _unassignedTeams;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Custom Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleCancel,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column - Available Teams
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.group,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Available Teams',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${unassignedTeams.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: unassignedTeams.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _allTeamsAssigned
                                          ? Icons.check_circle_outline
                                          : Icons.info_outline,
                                      size: 40,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _allTeamsAssigned
                                          ? 'All teams assigned!'
                                          : 'No teams available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(6),
                                itemCount: unassignedTeams.length,
                                itemBuilder: (context, index) {
                                  final team = unassignedTeams[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2196F3).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            team.name.isNotEmpty
                                                ? team.name[0].toUpperCase()
                                                : 'T',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2196F3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        team.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: team.division != null
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                team.division,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right Column - Create Matchups
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38A169),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sports_soccer,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Create Matchups',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${matchups.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Team Selection Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Select Teams',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Team 1 and Team 2 selectors
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: selectedTeam1 != null
                                                    ? const Color(0xFF2196F3)
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            child: DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                labelText: 'Team 1',
                                                labelStyle: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                              ),
                                              value: selectedTeam1,
                                              items: unassignedTeams.map((team) {
                                                return DropdownMenuItem<String>(
                                                  value: team.id,
                                                  child: Text(
                                                    team.name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedTeam1 = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2196F3).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'VS',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2196F3),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: selectedTeam2 != null
                                                    ? const Color(0xFF2196F3)
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            child: DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                labelText: 'Team 2',
                                                labelStyle: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                              ),
                                              value: selectedTeam2,
                                              items: unassignedTeams
                                                  .where((team) => team.id != selectedTeam1)
                                                  .map((team) {
                                                return DropdownMenuItem<String>(
                                                  value: team.id,
                                                  child: Text(
                                                    team.name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedTeam2 = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Add Matchup button
                                    ElevatedButton.icon(
                                      onPressed: (selectedTeam1 != null &&
                                              selectedTeam2 != null &&
                                              selectedTeam1 != selectedTeam2)
                                          ? _addMatchup
                                          : null,
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      label: const Text(
                                        'Add Matchup',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2196F3),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Matchups List
                              if (matchups.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sports_soccer,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No matchups created yet',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Select teams above and click "Add Matchup"',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...matchups.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final matchup = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2196F3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  matchup['team1'].name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 4,
                                                      height: 4,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF2196F3),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Text(
                                                      'VS',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  matchup['team2'].name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                            ),
                                            onPressed: () => _removeMatchup(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              // Show message if teams are left unassigned
                              if (!_allTeamsAssigned && matchups.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    border: Border.all(color: Colors.orange[200]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange[800],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${unassignedTeams.length} team(s) remaining. All teams must be assigned before creating the schedule.',
                                          style: TextStyle(
                                            color: Colors.orange[800],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _handleCancel,
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _allTeamsAssigned ? _createSchedule : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _allTeamsAssigned ? const Color(0xFF38A169) : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                _allTeamsAssigned ? 'Create Schedule' : 'Assign All Teams',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

