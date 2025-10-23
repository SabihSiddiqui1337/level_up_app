import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../models/playoff_match.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
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
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();

  // Division selection state
  String? _selectedDivision;
  List<String> _availableDivisions = [];

  // Cache for stable match generation
  final Map<String, List<Match>> _matchesCache = {};

  // Get teams based on sport type and selected division
  List<dynamic> get _teams {
    List<dynamic> allTeams = [];
    if (widget.sportName.toLowerCase().contains('basketball')) {
      allTeams = _teamService.teams;
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      allTeams = _pickleballTeamService.teams;
    }

    // Filter by selected division if one is selected
    if (_selectedDivision != null) {
      return allTeams
          .where((team) => team.division == _selectedDivision)
          .toList();
    }

    return allTeams;
  }

  // Update available divisions
  void _updateDivisions() {
    List<dynamic> allTeams = [];
    if (widget.sportName.toLowerCase().contains('basketball')) {
      allTeams = _teamService.teams;
    } else if (widget.sportName.toLowerCase().contains('pickleball')) {
      allTeams = _pickleballTeamService.teams;
    }

    Set<String> divisions =
        allTeams.map((team) => team.division as String).toSet();
    _availableDivisions = divisions.toList()..sort();

    // If no division is selected or selected division is not available, select first one
    if (_selectedDivision == null ||
        !_availableDivisions.contains(_selectedDivision)) {
      _selectedDivision =
          _availableDivisions.isNotEmpty ? _availableDivisions.first : null;
    }
  }

  // Get teams from service instead of hardcoded data
  List<Match> get _preliminaryMatches {
    final teams = _teams;
    if (teams.isEmpty) return [];

    // Create a cache key based on teams and division
    String cacheKey =
        '${widget.sportName}_${_selectedDivision ?? 'all'}_${teams.map((t) => t.id).join('_')}';

    // Return cached matches if available
    if (_matchesCache.containsKey(cacheKey)) {
      return _matchesCache[cacheKey]!;
    }

    // Generate matches from registered teams
    List<Match> matches = [];
    int matchId = 1;
    int courtNumber = 1;
    int timeSlot = 10; // Start at 10 AM

    // Group teams by division
    Map<String, List<dynamic>> teamsByDivision = {};
    for (var team in teams) {
      String division = team.division;
      if (!teamsByDivision.containsKey(division)) {
        teamsByDivision[division] = [];
      }
      teamsByDivision[division]!.add(team);
    }

    // Generate matches for each division separately
    for (String division in teamsByDivision.keys) {
      List<dynamic> divisionTeams = teamsByDivision[division]!;

      if (divisionTeams.length == 1) {
        // If only 1 team in division, show them as waiting for opponent
        matches.add(
          Match(
            id: '${matchId++}',
            day: 'Day 1',
            court: 'Court $courtNumber',
            time: '$timeSlot:00 AM',
            team1: divisionTeams[0].name,
            team2: 'Waiting for Opponent',
            team1Status: 'Ready',
            team2Status: 'TBD',
            team1Score: 0,
            team2Score: 0,
          ),
        );
        courtNumber = (courtNumber % 3) + 1;
        if (courtNumber == 1) timeSlot += 1;
      } else {
        // Use deterministic sorting instead of random shuffle for stability
        List<dynamic> sortedTeams = List.from(divisionTeams);
        sortedTeams.sort(
          (a, b) => a.name.compareTo(b.name),
        ); // Sort by name for consistency

        // Create a list to track which teams have played each other
        Map<String, Set<String>> playedAgainst = {};
        for (var team in sortedTeams) {
          playedAgainst[team.name] = <String>{};
        }

        // Generate exactly 3 games per team, ensuring no team plays the same opponent twice
        Map<String, int> gamesPlayed = {};
        for (var team in sortedTeams) {
          gamesPlayed[team.name] = 0;
        }

        int maxAttempts = 100; // Prevent infinite loops
        int attempts = 0;

        while (attempts < maxAttempts) {
          // Find teams that need more games
          List<dynamic> teamsNeedingGames =
              sortedTeams.where((team) => gamesPlayed[team.name]! < 3).toList();

          if (teamsNeedingGames.isEmpty) break;

          // Try to create a match between two teams that haven't played each other
          bool matchCreated = false;
          for (int i = 0; i < teamsNeedingGames.length && !matchCreated; i++) {
            for (
              int j = i + 1;
              j < teamsNeedingGames.length && !matchCreated;
              j++
            ) {
              String team1Name = teamsNeedingGames[i].name;
              String team2Name = teamsNeedingGames[j].name;

              // Check if these teams haven't played each other yet
              if (!playedAgainst[team1Name]!.contains(team2Name) &&
                  !playedAgainst[team2Name]!.contains(team1Name)) {
                // Create the match
                matches.add(
                  Match(
                    id: '${matchId++}',
                    day: 'Day 1',
                    court: 'Court $courtNumber',
                    time: '$timeSlot:00 AM',
                    team1: team1Name,
                    team2: team2Name,
                    team1Status: 'Not Checked-in',
                    team2Status: 'Not Checked-in',
                    team1Score: 0,
                    team2Score: 0,
                  ),
                );

                // Update tracking
                playedAgainst[team1Name]!.add(team2Name);
                playedAgainst[team2Name]!.add(team1Name);
                gamesPlayed[team1Name] = gamesPlayed[team1Name]! + 1;
                gamesPlayed[team2Name] = gamesPlayed[team2Name]! + 1;

                // Alternate courts and time slots
                courtNumber = (courtNumber % 3) + 1; // 3 courts max
                if (courtNumber == 1) {
                  timeSlot += 1; // Move to next hour
                }

                matchCreated = true;
              }
            }
          }

          if (!matchCreated) {
            // If we can't create more matches with current constraints, break
            break;
          }

          attempts++;
        }
      }
    }

    // Cache the matches for stability
    _matchesCache[cacheKey] = matches;
    return matches;
  }

  // Get standings from registered teams
  List<Standing> get _standings {
    final teams = _teams;
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

    // Sort by points (descending), then by wins (descending), then by losses (ascending)
    standings.sort((a, b) {
      // First priority: Points (higher is better)
      if (b.points != a.points) return b.points.compareTo(a.points);

      // Second priority: Wins (higher is better)
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);

      // Third priority: Losses (lower is better)
      return a.losses.compareTo(b.losses);
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
    final teams = _teams;
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
    final teams = _teams;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload teams when screen becomes visible
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();
    if (mounted) {
      setState(() {
        _updateDivisions();
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

              // Division Dropdown
              if (_availableDivisions.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2196F3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDivision,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF2196F3),
                        size: 20,
                      ),
                      hint: const Text(
                        'Select Division',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      items:
                          _availableDivisions.map((String division) {
                            return DropdownMenuItem<String>(
                              value: division,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  division,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDivision = newValue;
                        });
                      },
                    ),
                  ),
                ),
              ],

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
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  isScrollable: false,
                  tabs: const [
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Preliminary',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Standings',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Playoffs',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
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
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[600]!.withOpacity(0.2),
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
                    color: Colors.white,
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
                color: Colors.white,
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
                    color: Colors.white,
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
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Header Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: const BorderRadius.only(
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
    // For stats columns (W, L, D, PTS), use fixed width
    if (flex == 1) {
      return SizedBox(
        width: 30,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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

    // For team name column, use Expanded
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Team Logo (placeholder)
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sports, color: Colors.grey[800], size: 14),
          ),
          const SizedBox(width: 8),

          // Team Name
          Expanded(
            flex: 3,
            child: Text(
              standing.teamName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Stats - only W, L, D, PTS with consistent width
          SizedBox(
            width: 30,
            child: Text(
              '${standing.wins}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${standing.losses}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${standing.draws}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${standing.points}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
