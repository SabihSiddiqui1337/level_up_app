import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../services/team_service.dart';
import '../services/pickleball_team_service.dart';
import 'sport_schedule_screen.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import '../services/auth_service.dart';
import '../utils/role_utils.dart';

class ScheduleScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const ScheduleScreen({super.key, this.onHomePressed});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final EventService _eventService = EventService();
  List<Event> _scheduleEvents = [];
  List<Event> _resultsEvents = [];
  final TeamService _teamService = TeamService();
  final PickleballTeamService _pickleballTeamService = PickleballTeamService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isScheduleExpanded = true;
  bool _isResultsExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    await _eventService.initialize();
    await _teamService.loadTeams();
    await _pickleballTeamService.loadTeams();

    // Get all events and separate into schedule (not completed) and results (completed)
    final allEvents = _eventService.events;
    final completedEvents = await _eventService.getPastEvents();
    final completedIds = completedEvents.map((e) => e.id).toSet();

    if (mounted) {
      setState(() {
        _scheduleEvents = allEvents
            .where((e) => !completedIds.contains(e.id))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        _resultsEvents = completedEvents;
        _isLoading = false;
      });
    }
  }

  int _teamCountForEvent(Event event) {
    final lower = event.sportName.toLowerCase();
    if (lower.contains('pickleball') || lower.contains('pickelball')) {
      return _pickleballTeamService.teams
          .where((t) => t.eventId == event.id)
          .length;
    }
    return _teamService.teams.where((t) => t.eventId == event.id).length;
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

  Widget _buildEventCard(
    Event event,
    bool isCompleted,
  ) {
    final teamCount = _teamCountForEvent(event);
    final hasEnoughTeams = teamCount >= 8;
    final currentUser = _authService.currentUser;
    final isAdmin = currentUser != null && RoleUtils.isOwner(currentUser.role);

    // Determine which image to use based on sport name
    String? imagePath;
    final sportName = event.sportName;
    if (sportName.toLowerCase().contains('basketball')) {
      imagePath = 'assets/basketball.png';
    } else if (sportName.toLowerCase().contains('pickleball') ||
        sportName.toLowerCase().contains('pickelball')) {
      imagePath = 'assets/pickelball.png';
    } else if (sportName.toLowerCase().contains('volleyball')) {
      imagePath = 'assets/volleyball.png';
    } else if (sportName.toLowerCase().contains('soccer')) {
      imagePath = 'assets/soccer.png';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                children: [
                  // Background Image
                  if (imagePath != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
                  // Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: imagePath != null
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
                  // Content
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
                            if (event.division != null && event.division!.trim().isNotEmpty) ...[
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
                          event.title,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date
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
                                _formatDate(event.date),
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
                        // Location
                        Row(
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
                              child: Text(
                                event.locationName,
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Show error message for non-admin users if not enough teams
          if (!hasEnoughTeams && !isAdmin) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not enough teams registered. Waiting for ${8 - teamCount} more team${8 - teamCount == 1 ? '' : 's'} to start the game.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Results button at bottom
          if (isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SportScheduleScreen(
                        sportName: event.sportName,
                        tournamentTitle: event.title,
                        onHomePressed: widget.onHomePressed,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.emoji_events),
                label: const Text('View Results'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else if (hasEnoughTeams) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SportScheduleScreen(
                        sportName: event.sportName,
                        tournamentTitle: event.title,
                        onHomePressed: widget.onHomePressed,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.schedule),
                label: const Text('View Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
          child: RefreshIndicator(
            onRefresh: _loadEvents,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Schedule Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isScheduleExpanded = !_isScheduleExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Schedule',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE67E22),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: _isScheduleExpanded ? 0.5 : 0,
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

                        // Schedule Events (collapsible)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: _isScheduleExpanded
                              ? Column(
                                  children: [
                                    if (_scheduleEvents.isEmpty)
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
                                                'No scheduled events',
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
                                      ..._scheduleEvents.map((event) => _buildEventCard(event, false)),
                                    const SizedBox(height: 20),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Results Section
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isResultsExpanded = !_isResultsExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Results',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE67E22),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: _isResultsExpanded ? 0.5 : 0,
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

                        // Results Events (collapsible)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: _isResultsExpanded
                              ? Column(
                                  children: [
                                    if (_resultsEvents.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                                        child: Center(
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.emoji_events,
                                                size: 64,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No completed events',
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
                                      ..._resultsEvents.map((event) => _buildEventCard(event, true)),
                                    const SizedBox(height: 20),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
