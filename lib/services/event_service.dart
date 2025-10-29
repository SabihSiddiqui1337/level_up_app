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
  }) async {
    try {
      final newEvent = Event(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        date: date,
        locationName: locationName,
        locationAddress: locationAddress,
        sportName: sportName,
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
}
