// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Expanded;
import 'package:flutter/services.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_loading_widget.dart';
import '../services/event_service.dart';
import '../services/score_service.dart';
import '../models/event.dart';
import 'main_navigation_screen.dart';
import 'event_detail_screen.dart';
import 'team_registration_screen.dart';
import 'pickleball_team_registration_screen.dart';
import 'admin_team_selection_screen.dart';
import 'sport_schedule_screen.dart' hide Text, Container, BoxDecoration, SizedBox;
import '../services/auth_service.dart';

class UpcomingEventsScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const UpcomingEventsScreen({super.key, this.onHomePressed});

  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  bool _isCopying = false; // Add flag to prevent rapid copying
  final EventService _eventService = EventService();
  final ScoreService _scoreService = ScoreService();
  final AuthService _authService = AuthService();
  List<Event> _upcomingEvents = [];
  List<Event> _pastEvents = [];
  bool _isLoading = true;
  bool _isUpcomingExpanded = true; // Track expansion state for upcoming events
  bool _isPastExpanded = true; // Track expansion state for past events
  Map<String, bool> _eventStartedStatus = {}; // Cache for event started status

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
    _loadEvents();
  }

  // Load expansion state for sections
  Future<void> _loadExpansionState() async {
    final expansionState = await _scoreService.loadHomeExpansionState();
    if (mounted) {
      setState(() {
        _isUpcomingExpanded = expansionState['upcomingExpanded'] ?? true;
        _isPastExpanded = expansionState['pastExpanded'] ?? true;
      });
    }
  }

  // Save expansion state for sections
  Future<void> _saveExpansionState() async {
    await _scoreService.saveHomeExpansionState(
      _isUpcomingExpanded,
      _isPastExpanded,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload expansion state when screen becomes visible
    _loadExpansionState();
    // Reload events when screen becomes visible to show updated past events
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
    // Load upcoming events (exclude completed ones)
    final upcomingEvents = await _eventService.getUpcomingEventsExcludingCompleted();
    // Load past events
    final pastEvents = await _eventService.getPastEvents();
    
    // Calculate elapsed time and ensure minimum 1 second duration
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
    }
    
    // Check event started status for all events
    final Map<String, bool> eventStartedStatus = {};
    for (final event in upcomingEvents) {
      final isStarted = await _isEventStarted(event.sportName);
      eventStartedStatus[event.id] = isStarted;
    }
    
    if (mounted) {
      setState(() {
        _upcomingEvents = upcomingEvents;
        _pastEvents = pastEvents;
        _eventStartedStatus = eventStartedStatus;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(onHomePressed: widget.onHomePressed),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: AppLoadingWidget(size: 100))
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Upcoming Events Section - Always show with expand/collapse
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isUpcomingExpanded = !_isUpcomingExpanded;
                              // Save expansion state when changed
                              _saveExpansionState();
                            });
                          },
                          child: Row(
                            children: [
                              Text(
                                'Upcoming Events',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE67E22),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              AnimatedRotation(
                                turns: _isUpcomingExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFFE67E22),
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Show events or empty message (collapsible)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: _isUpcomingExpanded
                            ? Column(
                                children: [
                                  if (_upcomingEvents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No upcoming events',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._upcomingEvents.map((event) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: _buildSimpleEventCard(
                                event.title,
                                _formatDate(event.date),
                                event.locationName,
                                event.locationAddress,
                                event.sportName,
                                event,
                                isCompleted: false,
                              ),
                            )),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      
                      // Past Events Section - Always show with expand/collapse
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isPastExpanded = !_isPastExpanded;
                              // Save expansion state when changed
                              _saveExpansionState();
                            });
                          },
                          child: Row(
                            children: [
                              Text(
                                'Past Events',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE67E22),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              AnimatedRotation(
                                turns: _isPastExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFFE67E22),
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Past events content (collapsible) - Always show, even if empty
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: _isPastExpanded
                            ? Column(
                                children: [
                                  if (_pastEvents.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.event_busy,
                                              size: 64,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No past events',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    ..._pastEvents.map((event) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: _buildSimpleEventCard(
                                            event.title,
                                            _formatDate(event.date),
                                            event.locationName,
                                            event.locationAddress,
                                            event.sportName,
                                            event,
                                            isCompleted: true,
                                          ),
                                        )),
                                  const SizedBox(height: 20),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ), // Column closes
                ), // SingleChildScrollView closes
              ), // RefreshIndicator closes
            ),
          )
  );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}. ${months[date.month - 1]}. ${date.day}. ${date.year}';
  }

  Widget _buildSimpleEventCard(
    String title,
    String date,
    String location,
    String address,
    String sportName,
    Event? event,
    {bool isCompleted = false}
  ) {
    // Determine which image to use based on sport name
    String? imagePath;
    if (sportName.toLowerCase().contains('basketball')) {
      imagePath = 'assets/basketball.png';
    } else if (sportName.toLowerCase().contains('pickleball') ||
        sportName.toLowerCase().contains('pickelball')) {
      imagePath =
          'assets/pickelball.png'; // Note: using the actual filename with typo
    } else if (sportName.toLowerCase().contains('volleyball')) {
      imagePath = 'assets/volleyball.png';
    } else if (sportName.toLowerCase().contains('soccer')) {
      imagePath = 'assets/soccer.png';
    }
    // No default fallback - if sport doesn't match, use gradient background

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            // Background Image (only if imagePath exists)
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
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey[50]!],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Overlay - semi-transparent if image exists, or gradient if no image
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
                              Colors.black.withOpacity(0.5),
                              Colors.black.withOpacity(0.7),
                            ],
                          )
                          : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey[50]!],
                          ),
                ),
              ),
            ),
            // Content on top
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sport Name Badge with Division
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          sportName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ),
                      // Division badge (if available)
                      if (event?.division != null && event!.division!.trim().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            event.division!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE67E22),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 6,
                          color: Colors.black87,
                        ),
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          date,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 4,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Location with icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 4,
                                    color: Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    address,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 4,
                                          color: Colors.black87,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap:
                                      _isCopying
                                          ? null
                                          : () => _copyToClipboard(address),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action buttons
                  if (isCompleted)
                    // For completed events - "Details" and "Check Score" buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                      onPressed: () {
                              // Navigate to Event Detail screen
                        if (event != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailScreen(
                                      event: event,
                                      isCompleted: true,
                                      onCheckScore: () {
                                        // Navigate to Sport Schedule screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SportScheduleScreen(
                                sportName: event.sportName,
                                tournamentTitle: event.title,
                                            ),
                                          ),
                                        );
                                      },
                                      onSignUp: () {}, // Not used for completed events
                              ),
                            ),
                          );
                        }
                      },
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text(
                              'DETAILS',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate directly to Sport Schedule screen (Preliminary Rounds tab)
                              if (event != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SportScheduleScreen(
                                      sportName: event.sportName,
                                      tournamentTitle: event.title,
                                    ),
                                  ),
                                ).then((_) {
                                  // After navigation, ensure we're on Preliminary rounds tab
                                  // This is handled by the SportScheduleScreen's initial state
                                });
                              }
                            },
                      icon: const Icon(Icons.score, size: 16),
                      label: const Text(
                        'CHECK SCORE',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                          ),
                        ),
                      ],
                    )
                  else
                    // For upcoming events - Register and Details buttons
                    Builder(
                      builder: (context) {
                        final eventStarted = event != null ? (_eventStartedStatus[event.id] ?? false) : false;
                        return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                                onPressed: eventStarted
                                    ? null
                                    : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const MainNavigationScreen(
                                        initialIndex: 1,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.app_registration, size: 16),
                                label: Text(
                                  eventStarted ? 'EVENT STARTED' : 'REGISTER',
                                  style: const TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                                  backgroundColor: eventStarted
                                      ? Colors.grey[400]
                                      : const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                                  elevation: eventStarted ? 0 : 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Show details dialog or navigate to details screen
                              if (event != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailScreen(
                                      event: event,
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
                                        final sport = event.sportName.toLowerCase();
                                        if (sport.contains('pickleball') || sport.contains('pickelball')) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PickleballTeamRegistrationScreen(event: event),
                                            ),
                                          );
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TeamRegistrationScreen(event: event),
                                            ),
                                          );
                                              }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                _showEventDetails(
                                  title,
                                  date,
                                  location,
                                  address,
                                  sportName,
                                );
                              }
                            },
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text(
                              'DETAILS',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(
    String title,
    String date,
    String location,
    String address,
    String sportName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.calendar_today, 'Date', date),
              const SizedBox(height: 12),
              _buildDetailRowWithAddress(
                Icons.location_on,
                'Location',
                location,
                address,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            const MainNavigationScreen(initialIndex: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: Colors.white,
              ),
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2196F3)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowWithAddress(
    IconData icon,
    String label,
    String location,
    String address,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2196F3)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isCopying ? null : () => _copyToClipboard(address),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) async {
    if (_isCopying) return; // Prevent rapid clicking

    setState(() {
      _isCopying = true;
    });

    // Convert multi-line address to single line for copying
    final singleLineText = text.replaceAll('\n', ' ');
    await Clipboard.setData(ClipboardData(text: singleLineText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Address copied to clipboard!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF38A169),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Add delay before allowing another copy
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isCopying = false;
    });
  }
}
