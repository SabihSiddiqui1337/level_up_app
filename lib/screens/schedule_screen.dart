import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_app_bar.dart';
import 'sport_schedule_screen.dart';
import '../keys/schedule_screen/schedule_screen_keys.dart';
import '../services/event_service.dart';
import '../models/event.dart';

class ScheduleScreen extends StatefulWidget {
  final VoidCallback? onHomePressed;

  const ScheduleScreen({super.key, this.onHomePressed});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isExpanded = false;
  final EventService _eventService = EventService();
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    await _eventService.initialize();
    setState(() {
      _events = _eventService.events;
    });
  }

  String _getEventTitleForSport(String sportName) {
    final sportEvents =
        _events
            .where(
              (event) =>
                  event.sportName.toLowerCase() == sportName.toLowerCase(),
            )
            .toList();

    if (sportEvents.isEmpty) {
      return 'No sports event';
    }

    // Return the first event's title (or you could return the most recent)
    return sportEvents.first.title;
  }

  bool _hasEventForSport(String sportName) {
    return _events.any(
      (event) => event.sportName.toLowerCase() == sportName.toLowerCase(),
    );
  }

  Widget _buildSportsList() {
    // Check if there are any events at all
    if (_events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No sports event',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Build list of sport cards only for sports that have events
    final List<Widget> sportCards = [];

    // Check for Basketball events
    if (_hasEventForSport(ScheduleScreenKeys.basketball)) {
      sportCards.add(
        _buildSportCard(
          ScheduleScreenKeys.basketball,
          const Color(0xFFE67E22), // Orange
          Icons.sports_basketball,
          ScheduleScreenKeys.basketballTournament,
          _getEventTitleForSport(ScheduleScreenKeys.basketball),
        ),
      );
    }

    // Check for Pickleball events
    if (_hasEventForSport(ScheduleScreenKeys.pickleball)) {
      if (sportCards.isNotEmpty) {
        sportCards.add(const SizedBox(height: 16));
      }
      sportCards.add(
        _buildSportCard(
          ScheduleScreenKeys.pickleball,
          const Color(0xFF38A169), // Green
          Icons.sports_tennis,
          ScheduleScreenKeys.pickleballTournament,
          _getEventTitleForSport(ScheduleScreenKeys.pickleball),
        ),
      );
    }

    // If no sport cards were added (events exist but not for these sports)
    if (sportCards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No sports event',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: sportCards);
  }

  Future<void> _loadExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool('schedule_expansion_state') ?? false;
      setState(() {
        _isExpanded = isExpanded;
      });
    } catch (e) {
      print('Error loading expansion state: $e');
    }
  }

  Future<void> _saveExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('schedule_expansion_state', _isExpanded);
    } catch (e) {
      print('Error saving expansion state: $e');
    }
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Center(
                  child: Text(
                    ScheduleScreenKeys.screenTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE67E22),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Year Selector with Expandable Sports
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                          _saveExpansionState();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ScheduleScreenKeys.year2025,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Expandable Sports List
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child:
                            _isExpanded
                                ? Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: _buildSportsList(),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSportCard(
    String sportName,
    Color color,
    IconData icon,
    String tournamentTitle,
    String eventTitle,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => SportScheduleScreen(
                  sportName: sportName,
                  tournamentTitle:
                      eventTitle, // Use event title instead of tournament title
                  onHomePressed: widget.onHomePressed,
                ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  eventTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
