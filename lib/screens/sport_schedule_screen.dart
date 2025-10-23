import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../models/playoff_match.dart';
import '../services/team_service.dart';
import '../keys/schedule_screen/schedule_screen_keys.dart';

class SportScheduleScreen extends StatefulWidget {
  final String sportName;
  final String tournamentTitle;
  final VoidCallback? onHomePressed;

  const SportScheduleScreen({
    super.key,
    required this.sportName,
    required this.tournamentTitle,
    this.onHomePressed,
  });

  @override
  State<SportScheduleScreen> createState() => _SportScheduleScreenState();
}

class _SportScheduleScreenState extends State<SportScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TeamService _teamService = TeamService();

  // Get teams from service instead of hardcoded data
  List<Match> get _preliminaryMatches {
    final teams = _teamService.teams;
    if (teams.isEmpty) return [];

    // Generate matches from registered teams
    List<Match> matches = [];
    int matchId = 1;
    int courtNumber = 1;
    int timeSlot = 10; // Start at 10 AM

    if (teams.length == 1) {
      // If only 1 team, show them as waiting for opponent
      matches.add(
        Match(
          id: '${matchId++}',
          day: 'Day 1',
          court: 'Court $courtNumber',
          time: '$timeSlot:00 AM',
          team1: teams[0].name,
          team2: 'Waiting for Opponent',
          team1Status: 'Ready',
          team2Status: 'TBD',
          team1Score: 0,
          team2Score: 0,
        ),
      );
    } else {
      // Create matches between all teams (round-robin style)
      for (int i = 0; i < teams.length; i++) {
        for (int j = i + 1; j < teams.length; j++) {
          matches.add(
            Match(
              id: '${matchId++}',
              day: 'Day 1',
              court: 'Court $courtNumber',
              time: '$timeSlot:00 AM',
              team1: teams[i].name,
              team2: teams[j].name,
              team1Status: 'Not Checked-in',
              team2Status: 'Not Checked-in',
              team1Score: 0,
              team2Score: 0,
            ),
          );

          // Alternate courts and time slots
          courtNumber = (courtNumber % 3) + 1; // 3 courts max
          if (courtNumber == 1) {
            timeSlot += 1; // Move to next hour
          }
        }
      }
    }
    return matches;
  }

  // Get standings from registered teams
  List<Standing> get _standings {
    final teams = _teamService.teams;
    if (teams.isEmpty) return [];

    // Generate standings from registered teams with initial stats
    List<Standing> standings = [];
    for (int i = 0; i < teams.length; i++) {
      standings.add(
        Standing(
          rank: i + 1,
          teamName: teams[i].name,
          games: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          technicalFouls: 0,
          pointDifference: 0,
          points: 0,
        ),
      );
    }

    // Sort by points (descending), then by wins (descending)
    standings.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      return b.wins.compareTo(a.wins);
    });

    // Update ranks after sorting
    for (int i = 0; i < standings.length; i++) {
      standings[i] = Standing(
        rank: i + 1,
        teamName: standings[i].teamName,
        games: standings[i].games,
        wins: standings[i].wins,
        draws: standings[i].draws,
        losses: standings[i].losses,
        technicalFouls: standings[i].technicalFouls,
        pointDifference: standings[i].pointDifference,
        points: standings[i].points,
      );
    }

    return standings;
  }

  // Get semi-finals from registered teams
  List<PlayoffMatch> get _semiFinals {
    final teams = _teamService.teams;
    if (teams.length < 4) return [];

    return [
      PlayoffMatch(
        id: 'sf1',
        time: '00:00 AM',
        court: '-',
        team1: teams.isNotEmpty ? '1# ${teams[0].name}' : '1# TBD',
        team2: teams.length >= 4 ? '4# ${teams[3].name}' : '4# TBD',
        team1Score: 0,
        team2Score: 0,
        round: ScheduleScreenKeys.semiFinals,
      ),
      PlayoffMatch(
        id: 'sf2',
        time: '02:45 PM',
        court: '1',
        team1: teams.length >= 2 ? '2# ${teams[1].name}' : '2# TBD',
        team2: teams.length >= 3 ? '3# ${teams[2].name}' : '3# TBD',
        team1Score: 0,
        team2Score: 0,
        round: ScheduleScreenKeys.semiFinals,
      ),
    ];
  }

  // Get finals from registered teams
  List<PlayoffMatch> get _finals {
    final teams = _teamService.teams;
    if (teams.length < 2) return [];

    return [
      PlayoffMatch(
        id: 'f1',
        time: '04:15 PM',
        court: '1',
        team1: 'Winner SF1',
        team2: 'Winner SF2',
        team1Score: 0,
        team2Score: 0,
        round: ScheduleScreenKeys.finals,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    if (mounted) {
      setState(() {
        // Trigger rebuild to show updated teams
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back Button and Tournament Title
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Tournament Title
                    Expanded(
                      child: Text(
                        widget.tournamentTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.zero,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Preliminary Rounds'),
                    Tab(text: 'Standings'),
                    Tab(text: 'Playoffs'),
                  ],
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPreliminaryRoundsTab(),
                    _buildStandingsTab(),
                    _buildPlayoffsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreliminaryRoundsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child:
          _preliminaryMatches.isEmpty
              ? _buildEmptyMatchesState()
              : ListView.builder(
                itemCount: _preliminaryMatches.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMatchCard(_preliminaryMatches[index]),
                  );
                },
              ),
    );
  }

  Widget _buildMatchCard(Match match) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Section - Match Details (compact)
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Day
                Text(
                  match.day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                // Time
                Text(
                  match.time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Team 1 Section
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 1),
                // Team Name
                Text(
                  match.team1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                // Score
                Text(
                  '${ScheduleScreenKeys.scorePrefix} ${match.team1Score}',
                  style: const TextStyle(
                    color: Color(0xFFE67E22), // Orange
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // VS Separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ScheduleScreenKeys.vsText,
              style: TextStyle(
                color: Color(0xFFFFFF00), // Bright yellow
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          // Team 2 Section
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 1),
                // Team Name
                Text(
                  match.team2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                // Score
                Text(
                  '${ScheduleScreenKeys.scorePrefix} ${match.team2Score}',
                  style: const TextStyle(
                    color: Color(0xFFE67E22), // Orange
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child:
          _standings.isEmpty
              ? _buildEmptyStandingsState()
              : Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Header Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1976D2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildTableHeader(ScheduleScreenKeys.teamHeader, 3),
                          _buildTableHeader(ScheduleScreenKeys.winsHeader, 1),
                          _buildTableHeader(ScheduleScreenKeys.lossesHeader, 1),
                          _buildTableHeader(ScheduleScreenKeys.drawsHeader, 1),
                          _buildTableHeader(ScheduleScreenKeys.pointsHeader, 1),
                        ],
                      ),
                    ),

                    // Data Rows
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _standings.length,
                      itemBuilder: (context, index) {
                        return _buildStandingRow(_standings[index]);
                      },
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTableHeader(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStandingRow(Standing standing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${standing.rank}',
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Team Logo (placeholder)
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports, color: Color(0xFF2196F3), size: 16),
          ),
          const SizedBox(width: 12),

          // Team Name
          Expanded(
            flex: 3,
            child: Text(
              standing.teamName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Stats - only W, L, D, PTS
          _buildStatText('${standing.wins}', 1),
          _buildStatText('${standing.losses}', 1),
          _buildStatText('${standing.draws}', 1),
          _buildStatText('${standing.points}', 1),
        ],
      ),
    );
  }

  Widget _buildStatText(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPlayoffsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Semi-Finals Section
          _buildPlayoffSection('Semi-Finals', _semiFinals),
          const SizedBox(height: 24),
          // Finals Section
          _buildPlayoffSection('Finals', _finals),
        ],
      ),
    );
  }

  Widget _buildPlayoffSection(String title, List<PlayoffMatch> matches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE67E22),
          ),
        ),
        const SizedBox(height: 16),
        matches.isEmpty
            ? _buildEmptyPlayoffsState()
            : Column(
              children:
                  matches.map((match) => _buildPlayoffMatch(match)).toList(),
            ),
      ],
    );
  }

  Widget _buildPlayoffMatch(PlayoffMatch match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Time and Court
          Container(
            width: 80,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  match.time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Court: ${match.court}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Teams
          Expanded(
            child: Column(
              children: [
                if (match.team1 != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.team1!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'Score: ${match.team1Score}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (match.team1 != null && match.team2 != null)
                  const SizedBox(height: 8),
                if (match.team2 != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE67E22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.team2!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'Score: ${match.team2Score}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
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
    );
  }

  Widget _buildEmptyMatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_basketball, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Matches Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register teams to see preliminary rounds',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStandingsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Standings Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register teams to see standings',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlayoffsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.games, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Playoff matches will appear here',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
