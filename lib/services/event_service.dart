import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  List<Event> _events = [];
  static const String _eventsKey = 'events';

  // Initialize the service
  Future<void> initialize() async {
    await _loadEvents();
  }

  // Load events from SharedPreferences
  Future<void> _loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);

      if (eventsJson != null) {
        final List<dynamic> eventsList = json.decode(eventsJson);
        _events = eventsList.map((json) => Event.fromJson(json)).toList();
        print('Loaded ${_events.length} events from storage');
      } else {
        _events = [];
        print('No events found in storage');
      }
    } catch (e) {
      print('Error loading events: $e');
      _events = [];
    }
  }

  // Save events to SharedPreferences
  Future<void> _saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = json.encode(
        _events.map((event) => event.toJson()).toList(),
      );
      await prefs.setString(_eventsKey, eventsJson);
      print('Saved ${_events.length} events to storage');
    } catch (e) {
      print('Error saving events: $e');
    }
  }

  // Get all events
  List<Event> get events => List.from(_events);

  // Get events sorted by date (upcoming first)
  List<Event> get upcomingEvents {
    final now = DateTime.now();
    final upcoming = _events.where((event) => event.date.isAfter(now)).toList();
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  // Get events by sport
  List<Event> getEventsBySport(String sportName) {
    return _events
        .where(
          (event) => event.sportName.toLowerCase() == sportName.toLowerCase(),
        )
        .toList();
  }

  // Create a new event
  Future<bool> createEvent({
    required String title,
    required DateTime date,
    required String locationName,
    required String locationAddress,
    required String sportName,
    String? description,
    String? division,
  }) async {
    try {
      final newEvent = Event(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        date: date,
        locationName: locationName,
        locationAddress: locationAddress,
        sportName: sportName,
        description: description,
        division: division,
        createdAt: DateTime.now(),
      );

      _events.add(newEvent);
      await _saveEvents();
      print('Event created successfully: ${newEvent.title}');
      return true;
    } catch (e) {
      print('Error creating event: $e');
      return false;
    }
  }

  // Delete an event
  Future<bool> deleteEvent(String eventId) async {
    try {
      final initialLength = _events.length;
      _events.removeWhere((event) => event.id == eventId);

      if (_events.length < initialLength) {
        await _saveEvents();
        print('Event deleted successfully: $eventId');
        return true;
      } else {
        print('Event not found: $eventId');
        return false;
      }
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  // Update an event
  Future<bool> updateEvent(Event updatedEvent) async {
    try {
      final index = _events.indexWhere((event) => event.id == updatedEvent.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        await _saveEvents();
        print('Event updated successfully: ${updatedEvent.title}');
        return true;
      } else {
        print('Event not found for update: ${updatedEvent.id}');
        return false;
      }
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  // Get event by ID
  Event? getEventById(String eventId) {
    try {
      return _events.firstWhere((event) => event.id == eventId);
    } catch (e) {
      return null;
    }
  }

  // Clear all events (for testing purposes)
  Future<void> clearAllEvents() async {
    _events.clear();
    await _saveEvents();
    print('All events cleared');
  }

  // Track completed events (events where finals have been completed)
  static const String _completedEventsKey = 'completed_events';

  // Mark an event as completed (finals completed)
  Future<void> markEventCompleted(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedIds = prefs.getStringList(_completedEventsKey) ?? [];
      print('DEBUG: Marking event as completed - ID: $eventId');
      print('DEBUG: Current completed IDs before: $completedIds');
      if (!completedIds.contains(eventId)) {
        completedIds.add(eventId);
        await prefs.setStringList(_completedEventsKey, completedIds);
        print('DEBUG: Event $eventId marked as completed successfully');
        print('DEBUG: Completed IDs after: $completedIds');
      } else {
        print('DEBUG: Event $eventId was already marked as completed');
      }
    } catch (e) {
      print('Error marking event as completed: $e');
    }
  }

  // Check if an event is completed
  Future<bool> isEventCompleted(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedIds = prefs.getStringList(_completedEventsKey) ?? [];
      return completedIds.contains(eventId);
    } catch (e) {
      print('Error checking if event is completed: $e');
      return false;
    }
  }

  // Get completed events (past events)
  Future<List<Event>> getPastEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedIds = prefs.getStringList(_completedEventsKey) ?? [];
      print('DEBUG: Getting past events, completed IDs: $completedIds');
      final pastEvents = _events
          .where((event) => completedIds.contains(event.id))
          .toList();
      pastEvents.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
      print('DEBUG: Past events count: ${pastEvents.length}');
      return pastEvents;
    } catch (e) {
      print('Error getting past events: $e');
      return [];
    }
  }

  // Get upcoming events (exclude completed ones)
  Future<List<Event>> getUpcomingEventsExcludingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedIds = prefs.getStringList(_completedEventsKey) ?? [];
      print('DEBUG: Completed event IDs: $completedIds');
      print('DEBUG: Total events: ${_events.length}');
      
      final now = DateTime.now();
      final upcoming = _events
          .where((event) {
            final isCompleted = completedIds.contains(event.id);
            final isFuture = event.date.isAfter(now);
            print('DEBUG: Event "${event.title}" (${event.id}): completed=$isCompleted, future=$isFuture');
            return !isCompleted && isFuture;
          })
          .toList();
      upcoming.sort((a, b) => a.date.compareTo(b.date));
      print('DEBUG: Upcoming events (excluding completed): ${upcoming.length}');
      return upcoming;
    } catch (e) {
      print('Error getting upcoming events: $e');
      return [];
    }
  }

  // Find event by sport name and tournament title
  Event? findEventBySportAndTitle(String sportName, String tournamentTitle) {
    try {
      print('DEBUG: Searching for event - sportName: "$sportName", title: "$tournamentTitle"');
      print('DEBUG: Available events:');
      for (var event in _events) {
        print('  - "${event.sportName}" / "${event.title}" (id: ${event.id})');
      }
      
      final found = _events.firstWhere(
        (event) =>
            event.sportName.toLowerCase() == sportName.toLowerCase() &&
            event.title.toLowerCase() == tournamentTitle.toLowerCase(),
      );
      print('DEBUG: Found event: ${found.id} - "${found.title}"');
      return found;
    } catch (e) {
      print('DEBUG: Event not found - sportName: "$sportName", title: "$tournamentTitle", error: $e');
      return null;
    }
  }
}
