// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_app_bar.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import 'main_navigation_screen.dart';
import 'event_detail_screen.dart';
import 'team_registration_screen.dart';
import 'pickleball_team_registration_screen.dart';
import 'sport_schedule_screen.dart';

class UpcomingEventsScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const UpcomingEventsScreen({super.key, this.onHomePressed});

  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  bool _isCopying = false; // Add flag to prevent rapid copying
  final EventService _eventService = EventService();
  List<Event> _upcomingEvents = [];
  List<Event> _pastEvents = [];
  bool _isLoading = true;
  bool _isUpcomingExpanded = true; // Track expansion state for upcoming events
  bool _isPastExpanded = true; // Track expansion state for past events

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload events when screen becomes visible to show updated past events
    _loadEvents();
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
    
    if (mounted) {
      setState(() {
        _upcomingEvents = upcomingEvents;
        _pastEvents = pastEvents;
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
              ? const Center(child: CircularProgressIndicator())
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
                    // For completed events - only "Check Score" button
                    ElevatedButton.icon(
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
                          );
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
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    )
                  else
                    // For upcoming events - Register and Details buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
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
                            label: const Text(
                              'REGISTER',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
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
                              // Show details dialog or navigate to details screen
                              if (event != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailScreen(
                                      event: event,
                                      onSignUp: () {
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
