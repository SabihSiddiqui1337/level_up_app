import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/event.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  List<Event> _events = [];
  static const String _eventsKey = 'events';
  static const String _eventsCollection = 'events';

  // Check if Firebase is initialized
  bool _isFirebaseInitialized() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get Firestore instance (only if Firebase is initialized)
  FirebaseFirestore? _getFirestore() {
    if (_isFirebaseInitialized()) {
      return FirebaseFirestore.instance;
    }
    return null;
  }

  // Initialize the service
  Future<void> initialize() async {
    await _loadEvents();
  }

  // Load events from Firebase Firestore (with fallback to SharedPreferences)
  Future<void> _loadEvents() async {
    try {
      // Try to load from Firestore first (only if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          final snapshot = await firestore.collection(_eventsCollection).get();
          if (snapshot.docs.isNotEmpty) {
            _events = snapshot.docs.map((doc) {
              final data = doc.data();
              return Event.fromJson({
                ...data,
                'id': doc.id, // Use Firestore document ID
              });
            }).toList();
            print('Loaded ${_events.length} events from Firestore');
            
            // Also save to local storage as backup
            await _saveEventsToLocal();
            return;
          }
        } catch (e) {
          print('Error loading from Firestore (will try local): $e');
        }
      } else {
        print('Firebase not initialized, using local storage only');
      }

      // Fallback to local storage if Firestore fails or is empty
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);

      if (eventsJson != null) {
        final List<dynamic> eventsList = json.decode(eventsJson);
        final localEvents = eventsList.map((json) => Event.fromJson(json)).toList();
        print('Loaded ${localEvents.length} events from local storage');
        
        // Merge Firestore and local events (Firestore takes precedence)
        if (firestore != null) {
          // Try to get Firestore events one more time to ensure we have latest
          try {
            final snapshot = await firestore.collection(_eventsCollection).get();
            if (snapshot.docs.isNotEmpty) {
              final firestoreEvents = snapshot.docs.map((doc) {
                final data = doc.data();
                return Event.fromJson({
                  ...data,
                  'id': doc.id,
                });
              }).toList();
              
              // Merge: combine Firestore and local, prefer Firestore for duplicates
              final Map<String, Event> eventMap = {};
              for (var event in localEvents) {
                eventMap[event.id] = event;
              }
              for (var event in firestoreEvents) {
                eventMap[event.id] = event; // Firestore overwrites local
              }
              _events = eventMap.values.toList();
              print('Merged ${_events.length} events (Firestore + local)');
            } else {
              _events = localEvents;
              // Sync local to Firestore if Firestore is empty but we have local events
              if (_events.isNotEmpty) {
                await _syncEventsToFirestore();
              }
            }
          } catch (e) {
            print('Error merging Firestore events: $e, using local only');
            _events = localEvents;
          }
        } else {
          _events = localEvents;
        }
      } else {
        _events = [];
        print('No events found in storage');
      }
    } catch (e) {
      print('Error loading events: $e');
      _events = [];
    }
  }

  // Save events to local storage (backup)
  Future<void> _saveEventsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = json.encode(
        _events.map((event) => event.toJson()).toList(),
      );
      await prefs.setString(_eventsKey, eventsJson);
      print('Saved ${_events.length} events to local storage');
    } catch (e) {
      print('Error saving events to local: $e');
    }
  }

  // Sync events to Firestore
  Future<void> _syncEventsToFirestore() async {
    final firestore = _getFirestore();
    if (firestore == null) {
      print('Firebase not initialized, skipping Firestore sync');
      return;
    }
    
    try {
      final batch = firestore.batch();
      for (final event in _events) {
        final docRef = firestore.collection(_eventsCollection).doc(event.id);
        batch.set(docRef, event.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
      print('Synced ${_events.length} events to Firestore');
    } catch (e) {
      print('Error syncing events to Firestore: $e');
      // Don't throw - local storage will still work
    }
  }

  // Save events to both Firestore and local storage
  Future<void> _saveEvents() async {
    try {
      // Save to Firestore
      await _syncEventsToFirestore();
      
      // Also save to local storage as backup
      await _saveEventsToLocal();
      
      print('Saved ${_events.length} events to Firestore and local storage');
    } catch (e) {
      print('Error saving events: $e');
      // Try local storage as fallback
      try {
        await _saveEventsToLocal();
      } catch (localError) {
        print('Error saving to local storage: $localError');
      }
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
      final eventId = DateTime.now().millisecondsSinceEpoch.toString();
      final newEvent = Event(
        id: eventId,
        title: title,
        date: date,
        locationName: locationName,
        locationAddress: locationAddress,
        sportName: sportName,
        description: description,
        division: division,
        createdAt: DateTime.now(),
      );

      // Save to Firestore first (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          await firestore.collection(_eventsCollection).doc(eventId).set(newEvent.toJson());
          print('Event created in Firestore: ${newEvent.title}');
        } catch (e) {
          print('Error saving to Firestore (will use local): $e');
        }
      }

      // Add to local list and save
      _events.add(newEvent);
      await _saveEventsToLocal();
      
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
      // Delete from Firestore first (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          await firestore.collection(_eventsCollection).doc(eventId).delete();
          print('Event deleted from Firestore: $eventId');
        } catch (e) {
          print('Error deleting from Firestore: $e');
          // Continue with local deletion even if Firestore fails
        }
      }

      // Delete from local list
      final initialLength = _events.length;
      _events.removeWhere((event) => event.id == eventId);

      if (_events.length < initialLength) {
        await _saveEventsToLocal();
        
        // Also remove from completed events list if it was there
        final prefs = await SharedPreferences.getInstance();
        final completedIds = prefs.getStringList(_completedEventsKey) ?? [];
        if (completedIds.contains(eventId)) {
          completedIds.remove(eventId);
          await prefs.setStringList(_completedEventsKey, completedIds);
        }
        
        print('Event deleted successfully: $eventId');
        return true;
      } else {
        print('Event not found in local list: $eventId');
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
      // Update in Firestore (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          await firestore.collection(_eventsCollection).doc(updatedEvent.id).set(
            updatedEvent.toJson(),
            SetOptions(merge: true),
          );
          print('Event updated in Firestore: ${updatedEvent.title}');
        } catch (e) {
          print('Error updating in Firestore: $e');
        }
      }

      // Update in local list
      final index = _events.indexWhere((event) => event.id == updatedEvent.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        await _saveEventsToLocal();
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
      // Update in Firestore (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          await firestore.collection(_eventsCollection).doc(eventId).update({
            'isCompleted': true,
            'completedAt': DateTime.now().toIso8601String(),
          });
          print('Event marked as completed in Firestore: $eventId');
        } catch (e) {
          print('Error updating Firestore: $e');
        }
      }

      // Also update local storage
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
      // Check Firestore first (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          final doc = await firestore.collection(_eventsCollection).doc(eventId).get();
          if (doc.exists && doc.data() != null) {
            final isCompleted = doc.data()!['isCompleted'] ?? false;
            if (isCompleted) return true;
          }
        } catch (e) {
          print('Error checking Firestore: $e');
        }
      }
      
      // Fallback to local storage
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
      // Reload events from Firestore to get latest updates
      await _loadEvents();
      
      // Get completed IDs from both Firestore and local storage
      List<String> completedIds = [];
      
      // Try Firestore first (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          final completedSnapshot = await firestore
              .collection(_eventsCollection)
              .where('isCompleted', isEqualTo: true)
              .get();
          completedIds = completedSnapshot.docs.map((doc) => doc.id).toList();
        } catch (e) {
          print('Error loading completed events from Firestore: $e');
        }
      }
      
      // Also check local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final localCompletedIds = prefs.getStringList(_completedEventsKey) ?? [];
        completedIds = [...completedIds, ...localCompletedIds].toSet().toList();
      } catch (e) {
        print('Error loading completed events from local: $e');
      }
      
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
      // Reload events from Firestore to get latest updates
      await _loadEvents();
      
      // Get completed IDs from both Firestore and local storage
      List<String> completedIds = [];
      
      // Try Firestore first (if Firebase is initialized)
      final firestore = _getFirestore();
      if (firestore != null) {
        try {
          final completedSnapshot = await firestore
              .collection(_eventsCollection)
              .where('isCompleted', isEqualTo: true)
              .get();
          completedIds = completedSnapshot.docs.map((doc) => doc.id).toList();
        } catch (e) {
          print('Error loading completed events from Firestore: $e');
        }
      }
      
      // Also check local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final localCompletedIds = prefs.getStringList(_completedEventsKey) ?? [];
        completedIds = [...completedIds, ...localCompletedIds].toSet().toList();
      } catch (e) {
        print('Error loading completed events from local: $e');
      }
      
      print('DEBUG: Completed event IDs: $completedIds');
      print('DEBUG: Total events: ${_events.length}');
      
      final now = DateTime.now();
      // Remove time component for date comparison (compare only dates)
      final nowDateOnly = DateTime(now.year, now.month, now.day);
      
      final upcoming = _events
          .where((event) {
            final isCompleted = completedIds.contains(event.id);
            // Compare dates only (ignore time) - event is upcoming if date >= today
            final eventDateOnly = DateTime(event.date.year, event.date.month, event.date.day);
            final isFuture = eventDateOnly.isAfter(nowDateOnly) || eventDateOnly.isAtSameMomentAs(nowDateOnly);
            
            print('DEBUG: Event "${event.title}" (${event.id}): '
                  'completed=$isCompleted, '
                  'eventDate=${event.date.toIso8601String()}, '
                  'now=${now.toIso8601String()}, '
                  'isFuture=$isFuture');
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
