import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../models/playoff_match.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSemiFinalsSelected = true;

  // Sample data - in real app, this would come from API
  final List<Match> _preliminaryMatches = [
    const Match(
      id: '1',
      day: 'Day 2',
      court: 'Court 1',
      time: '11:15 AM',
      team1: 'Endgame',
      team2: 'Ramadan Fast Breakers',
      team1Status: 'Not Checked-in',
      team2Status: 'Checked-in',
      team1Score: 64,
      team2Score: 31,
    ),
    const Match(
      id: '2',
      day: 'Day 2',
      court: 'Court 1',
      time: '12:00 PM',
      team1: 'Ramadan Fast Breakers',
      team2: 'Snook Showtyme',
      team1Status: 'Checked-in',
      team2Status: 'Not Checked-in',
      team1Score: 22,
      team2Score: 83,
    ),
    const Match(
      id: '3',
      day: 'Day 2',
      court: 'Court 1',
      time: '12:45 PM',
      team1: 'Endgame',
      team2: 'Snook Showtyme',
      team1Status: 'Not Checked-in',
      team2Status: 'Not Checked-in',
      team1Score: 78,
      team2Score: 85,
    ),
    const Match(
      id: '4',
      day: 'Day 2',
      court: 'Court 2',
      time: '1:30 PM',
      team1: 'Thunder Bolts',
      team2: 'Lightning Strikes',
      team1Status: 'Checked-in',
      team2Status: 'Checked-in',
      team1Score: 45,
      team2Score: 52,
    ),
    const Match(
      id: '5',
      day: 'Day 2',
      court: 'Court 2',
      time: '2:15 PM',
      team1: 'Fire Dragons',
      team2: 'Ice Warriors',
      team1Status: 'Not Checked-in',
      team2Status: 'Checked-in',
      team1Score: 67,
      team2Score: 43,
    ),
    const Match(
      id: '6',
      day: 'Day 2',
      court: 'Court 3',
      time: '3:00 PM',
      team1: 'Storm Riders',
      team2: 'Wind Walkers',
      team1Status: 'Checked-in',
      team2Status: 'Not Checked-in',
      team1Score: 38,
      team2Score: 41,
    ),
  ];

  final List<Standing> _standings = [
    const Standing(
      rank: 1,
      teamName: 'Snook Showtyme',
      games: 2,
      wins: 2,
      draws: 0,
      losses: 0,
      technicalFouls: 0,
      pointDifference: 65,
      points: 6,
    ),
    const Standing(
      rank: 2,
      teamName: 'Endgame',
      games: 2,
      wins: 1,
      draws: 0,
      losses: 1,
      technicalFouls: 0,
      pointDifference: 18,
      points: 3,
    ),
    const Standing(
      rank: 3,
      teamName: 'Ramadan Fast Breakers',
      games: 2,
      wins: 0,
      draws: 0,
      losses: 2,
      technicalFouls: 0,
      pointDifference: -83,
      points: 0,
    ),
    const Standing(
      rank: 4,
      teamName: 'Thunder Bolts',
      games: 1,
      wins: 1,
      draws: 0,
      losses: 0,
      technicalFouls: 0,
      pointDifference: 7,
      points: 3,
    ),
    const Standing(
      rank: 5,
      teamName: 'Lightning Strikes',
      games: 1,
      wins: 0,
      draws: 0,
      losses: 1,
      technicalFouls: 0,
      pointDifference: -7,
      points: 0,
    ),
    const Standing(
      rank: 6,
      teamName: 'Fire Dragons',
      games: 1,
      wins: 1,
      draws: 0,
      losses: 0,
      technicalFouls: 0,
      pointDifference: 24,
      points: 3,
    ),
    const Standing(
      rank: 7,
      teamName: 'Ice Warriors',
      games: 1,
      wins: 0,
      draws: 0,
      losses: 1,
      technicalFouls: 0,
      pointDifference: -24,
      points: 0,
    ),
    const Standing(
      rank: 8,
      teamName: 'Storm Riders',
      games: 1,
      wins: 0,
      draws: 0,
      losses: 1,
      technicalFouls: 0,
      pointDifference: -3,
      points: 0,
    ),
    const Standing(
      rank: 9,
      teamName: 'Wind Walkers',
      games: 1,
      wins: 1,
      draws: 0,
      losses: 0,
      technicalFouls: 0,
      pointDifference: 3,
      points: 3,
    ),
  ];

  final List<PlayoffMatch> _semiFinals = [
    const PlayoffMatch(
      id: 'sf1',
      time: '00:00 AM',
      court: '-',
      team1: '1# TBD',
      team2: '4# TBD',
      team1Score: 0,
      team2Score: 0,
      round: 'Semi-Finals',
    ),
    const PlayoffMatch(
      id: 'sf2',
      time: '02:45 PM',
      court: '1',
      team1: '2# TBD',
      team2: '3# TBD',
      team1Score: 1,
      team2Score: 0,
      round: 'Semi-Finals',
    ),
  ];

  final List<PlayoffMatch> _finals = [
    const PlayoffMatch(
      id: 'f1',
      time: '04:15 PM',
      court: '1',
      team1: 'Winner SF1',
      team2: 'Winner SF2',
      team1Score: 0,
      team2Score: 0,
      round: 'Finals',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Preliminary Rounds
                          _buildPreliminaryRounds(),
                          const SizedBox(height: 24),

                          // Standings
                          _buildStandings(),
                          const SizedBox(height: 24),

                          // Playoffs
                          _buildPlayoffs(),
                          const SizedBox(height: 24), // Extra padding at bottom
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
    );
  }

  Widget _buildPreliminaryRounds() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Preliminary Rounds',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE67E22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Scrollable Match Cards
        SizedBox(
          height: 175, // Fixed height for scrollable area
          child: ListView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _preliminaryMatches.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMatchCard(_preliminaryMatches[index]),
              );
            },
          ),
        ),
      ],
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
                  'Score: ${match.team1Score}',
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
              'VS',
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
                  'Score: ${match.team2Score}',
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

  Widget _buildStandings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Standings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE67E22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Scrollable Table
        Container(
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
                    _buildTableHeader('Team', 2),
                    _buildTableHeader('Games', 1),
                    _buildTableHeader('W', 1),
                    _buildTableHeader('D', 1),
                    _buildTableHeader('L', 1),
                    _buildTableHeader('T/Fouls', 1),
                    _buildTableHeader('+/-', 1),
                    _buildTableHeader('PTS', 1),
                  ],
                ),
              ),

              // Scrollable Data Rows
              SizedBox(
                height: 200, // Fixed height for scrollable area
                child: ListView.builder(
                  itemCount: _standings.length,
                  itemBuilder: (context, index) {
                    return _buildStandingRow(_standings[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStandingRow(Standing standing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 24,
            height: 24,
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
          const SizedBox(width: 8),

          // Team Logo (placeholder)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports, color: Color(0xFF2196F3), size: 16),
          ),
          const SizedBox(width: 8),

          // Team Name
          Expanded(
            flex: 2,
            child: Text(
              standing.teamName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),

          // Stats
          _buildStatText('${standing.games}', 1),
          _buildStatText('${standing.wins}', 1),
          _buildStatText('${standing.draws}', 1),
          _buildStatText('${standing.losses}', 1),
          _buildStatText('${standing.technicalFouls}', 1),
          _buildStatText('${standing.pointDifference}', 1),
          _buildStatText('${standing.points}', 1),
        ],
      ),
    );
  }

  Widget _buildStatText(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPlayoffs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.games, color: const Color(0xFFE67E22), size: 30),
            const SizedBox(width: 8),
            Text(
              'Playoffs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE67E22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tabs
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSemiFinalsSelected = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          _isSemiFinalsSelected
                              ? const Color(0xFF2196F3)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Semi-Finals',
                      style: TextStyle(
                        color:
                            _isSemiFinalsSelected
                                ? Colors.white
                                : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSemiFinalsSelected = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          !_isSemiFinalsSelected
                              ? const Color(0xFF2196F3)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Finals',
                      style: TextStyle(
                        color:
                            !_isSemiFinalsSelected
                                ? Colors.white
                                : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Playoff Matches
        if (_isSemiFinalsSelected)
          ..._semiFinals.map((match) => _buildPlayoffMatch(match))
        else
          ..._finals.map((match) => _buildPlayoffMatch(match)),
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
}
