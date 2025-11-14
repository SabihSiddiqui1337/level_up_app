import 'package:flutter/material.dart';
import 'team_registration_screen.dart';
import 'pickleball_team_registration_screen.dart';
import 'admin_team_selection_screen.dart';
import 'event_detail_screen.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../services/score_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_app_bar.dart';

class GameSelectionScreen extends StatefulWidget {
  final Function(Team) onSave;
  final Function(PickleballTeam)? onSavePickleball;
  final VoidCallback? onHomePressed;

  const GameSelectionScreen({
    super.key,
    required this.onSave,
    this.onSavePickleball,
    this.onHomePressed,
  });

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  final EventService _eventService = EventService();
  final ScoreService _scoreService = ScoreService();
  final AuthService _authService = AuthService();
  List<Event> _events = [];
  List<String> _sportNames = [];
  bool _isLoading = true;
  Map<String, bool> _eventStartedStatus = {}; // Cache for event started status

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload events when screen becomes visible to exclude newly completed events
    _loadEvents();
  }

  // Check if playoffs have started and any score is set for a sport
  Future<bool> _isEventStarted(String sportName) async {
    try {
      // Check all possible divisions for this sport
      final divisions = ['all', 'Youth (18 or under)', 'Adult 18+'];
      bool hasPlayoffsStarted = false;
      bool hasAnyScores = false;
      
      for (final division in divisions) {
        // Check if playoffs have started for this division
        final playoffsStarted = await _scoreService.loadPlayoffsStartedForDivision(division);
        if (playoffsStarted) {
          hasPlayoffsStarted = true;
          
          // Check if any playoff scores exist
          final qfScores = await _scoreService.loadQuarterFinalsScoresForDivision(division);
          final sfScores = await _scoreService.loadSemiFinalsScoresForDivision(division);
          final finalsScores = await _scoreService.loadFinalsScoresForDivision(division);
          
          // Check if any scores exist (not empty and not all zeros)
          if (qfScores.isNotEmpty) {
            for (final matchScores in qfScores.values) {
              if (matchScores.values.any((score) => score > 0)) {
                hasAnyScores = true;
                break;
              }
            }
          }
          if (!hasAnyScores && sfScores.isNotEmpty) {
            for (final matchScores in sfScores.values) {
              if (matchScores.values.any((score) => score > 0)) {
                hasAnyScores = true;
                break;
              }
            }
          }
          if (!hasAnyScores && finalsScores.isNotEmpty) {
            for (final matchScores in finalsScores.values) {
              if (matchScores.values.any((score) => score > 0)) {
                hasAnyScores = true;
                break;
              }
            }
          }
          
          if (hasAnyScores) break;
        }
      }
      
      return hasPlayoffsStarted && hasAnyScores;
    } catch (e) {
      print('Error checking if event started: $e');
      return false;
    }
  }

  Future<void> _loadEvents() async {
    // Ensure refresh indicator shows for at least 1 second
    final startTime = DateTime.now();
    
    await _eventService.initialize();
    // Load upcoming events excluding completed ones
    final upcomingEvents = await _eventService.getUpcomingEventsExcludingCompleted();
    
    // Check event started status for all events
    final Map<String, bool> eventStartedStatus = {};
    for (final event in upcomingEvents) {
      final isStarted = await _isEventStarted(event.sportName);
      eventStartedStatus[event.sportName] = isStarted;
    }
    
    // Calculate elapsed time and ensure minimum 1 second duration
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
    }
    
    if (mounted) {
      setState(() {
        _events = upcomingEvents;
        // Get unique sport names from events
        _sportNames = _events.map((e) => e.sportName).toSet().toList();
        _eventStartedStatus = eventStartedStatus;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a sport to register your team:',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              _buildRegularGameSelection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegularGameSelection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sportNames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sports available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check upcoming events for available sports',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: (_sportNames.length / 2).ceil() * 200.0, // Approximate height based on items
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _sportNames.length,
        itemBuilder: (context, index) {
        final sportName = _sportNames[index];
        final icon = _getSportIcon(sportName);
        final color = _getSportColor(index);

        // Find the first upcoming event for this sport
        final eventsForSport = _events
            .where((e) => e.sportName.toLowerCase() == sportName.toLowerCase())
            .toList();
        final event = eventsForSport.isNotEmpty ? eventsForSport.first : null;
        
        // Check if event has started
        final isEventStarted = _eventStartedStatus[sportName] ?? false;
        
        return _buildGameCard(
          context, 
          sportName, 
          icon, 
          color, 
          event?.title ?? sportName, // Show event title if available, otherwise sport name
          () async {
            if (isEventStarted) {
              return; // Don't navigate if event has started
            }
            
            if (event == null) {
              // Fallback: go directly to registration if no event found
              // Without an event, owners/admins still go to regular registration
              if (sportName.toLowerCase().contains('pickleball')) {
                _navigateToPickleballRegistration(context);
              } else {
                _navigateToTeamRegistration(context, sportName);
              }
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(
                  event: event,
                  onHomePressed: widget.onHomePressed,
                  onSignUp: () {
                    // Check if user is owner/admin
                    final currentUser = _authService.currentUser;
                    final isOwnerOrAdmin = currentUser?.role == 'owner' || 
                                            currentUser?.role == 'scoring';
                    
                    if (isOwnerOrAdmin) {
                      // Navigate to admin team selection screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminTeamSelectionScreen(event: event),
                        ),
                      );
                    } else {
                      // Regular users go to team registration
                      if (sportName.toLowerCase().contains('pickleball')) {
                        _navigateToPickleballRegistration(context, event: event);
                      } else {
                        _navigateToTeamRegistration(context, sportName, event: event);
                      }
                    }
                  },
                ),
              ),
            );
          },
          isEventStarted: isEventStarted,
        );
      },
      ),
    );
  }

  IconData _getSportIcon(String sportName) {
    final lowerSport = sportName.toLowerCase();
    if (lowerSport.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lowerSport.contains('pickleball') ||
        lowerSport.contains('tennis')) {
      return Icons.sports_tennis;
    } else if (lowerSport.contains('soccer') ||
        lowerSport.contains('football')) {
      return Icons.sports_soccer;
    } else if (lowerSport.contains('volleyball')) {
      return Icons.sports_volleyball;
    } else {
      return Icons.sports;
    }
  }

  Color _getSportColor(int index) {
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF38A169), // Green
      const Color(0xFFE67E22), // Orange
      const Color(0xFF9B59B6), // Purple
      const Color(0xFFE74C3C), // Red
      const Color(0xFF3498DB), // Light Blue
    ];
    return colors[index % colors.length];
  }

  Widget _buildGameCard(
    BuildContext context,
    String gameName,
    IconData icon,
    Color color,
    String displayTitle, // Event title or sport name
    VoidCallback onTap, {
    bool isEventStarted = false,
  }) {
    // Determine which image to use based on sport name
    String? imagePath;
    if (gameName.toLowerCase().contains('basketball')) {
      imagePath = 'assets/basketball.png';
    } else if (gameName.toLowerCase().contains('pickleball') ||
        gameName.toLowerCase().contains('pickelball')) {
      imagePath =
          'assets/pickelball.png'; // Note: using the actual filename with typo
    } else if (gameName.toLowerCase().contains('volleyball')) {
      imagePath = 'assets/volleyball.png';
    } else if (gameName.toLowerCase().contains('soccer')) {
      imagePath = 'assets/soccer.png';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card with image/background and icon
        Card(
          elevation: isEventStarted ? 2 : 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              InkWell(
                onTap: isEventStarted ? null : onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Background Image (only if image exists)
                      if (imagePath != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to gradient if image fails to load
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color, color.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      // Gradient overlay if no image, or semi-transparent overlay if image exists
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient:
                                imagePath != null
                                    ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(isEventStarted ? 0.5 : 0.2),
                                        Colors.black.withOpacity(isEventStarted ? 0.7 : 0.4),
                                      ],
                                    )
                                    : LinearGradient(
                                      colors: [
                                        isEventStarted ? color.withOpacity(0.5) : color,
                                        isEventStarted ? color.withOpacity(0.3) : color.withOpacity(0.8)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Event Started overlay
              if (isEventStarted)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Event Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        // Text below the card - show event title if available, otherwise sport name
        const SizedBox(height: 12),
        Text(
          displayTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isEventStarted ? Colors.grey[500] : Colors.grey[800],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _navigateToTeamRegistration(BuildContext context, String gameType, {Event? event}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TeamRegistrationScreen(
              event: event,
              onSave: (team) {
                // Add game type to team
                final teamWithGame = Team(
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
                  eventId: event?.id ?? team.eventId,
                );

                widget.onSave(teamWithGame);
                Navigator.pop(context); // Go back to home screen
              },
            ),
      ),
    );
  }

  void _navigateToPickleballRegistration(BuildContext context, {Event? event}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PickleballTeamRegistrationScreen(
              event: event,
              onSave: (team) {
                if (widget.onSavePickleball != null) {
                  widget.onSavePickleball!(team);
                }
                Navigator.pop(context); // Go back to home screen
              },
            ),
      ),
    );
  }
}
