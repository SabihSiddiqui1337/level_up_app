import 'package:flutter/material.dart';
import 'team_registration_screen.dart';
import 'pickleball_team_registration_screen.dart';
import 'event_detail_screen.dart';
import '../models/team.dart';
import '../models/pickleball_team.dart';
import '../models/event.dart';
import '../services/event_service.dart';
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
  List<Event> _events = [];
  List<String> _sportNames = [];
  bool _isLoading = true;

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

  Future<void> _loadEvents() async {
    // Ensure refresh indicator shows for at least 1 second
    final startTime = DateTime.now();
    
    await _eventService.initialize();
    // Load upcoming events excluding completed ones
    final upcomingEvents = await _eventService.getUpcomingEventsExcludingCompleted();
    
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
      height: (_sportNames.length / 2).ceil() * 200.0, // Approximate height based on itemsd
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
        
        return _buildGameCard(
          context, 
          sportName, 
          icon, 
          color, 
          event?.title ?? sportName, // Show event title if available, otherwise sport name
          () async {
            if (event == null) {
              // Fallback: go directly to registration if no event found
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
                    // Navigate to appropriate registration form
                    if (sportName.toLowerCase().contains('pickleball')) {
                      _navigateToPickleballRegistration(context, event: event);
                    } else {
                      _navigateToTeamRegistration(context, sportName, event: event);
                    }
                  },
                ),
              ),
            );
          },
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
    VoidCallback onTap,
  ) {
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
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
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
                                    Colors.black.withOpacity(0.2),
                                    Colors.black.withOpacity(0.4),
                                  ],
                                )
                                : LinearGradient(
                                  colors: [color, color.withOpacity(0.8)],
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
        ),
        // Text below the card - show event title if available, otherwise sport name
        const SizedBox(height: 12),
        Text(
          displayTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
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
