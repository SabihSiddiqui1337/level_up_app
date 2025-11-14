import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../screens/update_prompt_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/pickleball_team_registration_screen.dart';
import '../screens/team_registration_screen.dart';
import 'event_service.dart';

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  print('Background message data: ${message.data}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static const String _fcmTokenKey = 'fcm_token';
  static const String _notificationPermissionKey = 'notification_permission_requested';
  static const String _fcmTokensCollection = 'fcm_tokens';
  
  bool _isInitialized = false;
  String? _fcmToken;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup message handlers
      _setupMessageHandlers();

      // Try to get FCM token (will only work if permission is already granted)
      await _getFCMToken();

      _isInitialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Handle notification tap (local notification)
  void _onNotificationTapped(NotificationResponse response) async {
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // The payload contains the eventId
        final eventId = response.payload!;
        print('Local notification tapped with payload: $eventId');
        await _navigateToEvent(eventId);
      } catch (e) {
        print('❌ Error handling notification tap: $e');
      }
    }
  }

  // Navigate to event (using navigator key)
  Future<void> _navigateToEvent(String eventId) async {
    try {
      // Get event from EventService
      final eventService = EventService();
      await eventService.initialize();
      final event = eventService.getEventById(eventId);
      
      if (event != null && navigatorKey.currentContext != null) {
        // Navigate to event detail screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(
              event: event,
              onSignUp: () {
                // Handle sign up navigation based on sport
                // Use navigator key context to ensure navigation works from any context
                final navContext = navigatorKey.currentContext;
                if (navContext != null) {
                  final sport = event.sportName.toLowerCase();
                  if (sport.contains('pickleball') || sport.contains('pickelball')) {
                    Navigator.push(
                      navContext,
                      MaterialPageRoute(
                        builder: (context) => PickleballTeamRegistrationScreen(event: event),
                      ),
                    );
                  } else {
                    Navigator.push(
                      navContext,
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
        print('✅ Navigated to event: ${event.title}');
      } else {
        print('⚠️ Event not found or navigator not available: $eventId');
      }
    } catch (e) {
      print('❌ Error navigating to event: $e');
    }
  }

  // Request notification permission (public method)
  Future<bool> requestPermission() async {
    return await _requestPermission();
  }

  // Request notification permission (private method)
  Future<bool> _requestPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await prefs.setBool(_notificationPermissionKey, true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
        // Get FCM token after permission is granted
        await _getFCMToken();
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
        // Get FCM token after permission is granted
        await _getFCMToken();
        return true;
      } else {
        print('❌ User denied notification permission');
        return false;
      }
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  // Check if permission was requested (for first launch check)
  Future<bool> hasRequestedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPermissionKey) ?? false;
  }

  // Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('✅ FCM Token: $_fcmToken');
        await _saveFCMTokenToFirestore(_fcmToken!);
        await _saveFCMTokenLocally(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMTokenToFirestore(newToken);
        _saveFCMTokenLocally(newToken);
        print('✅ FCM Token refreshed: $newToken');
      });

      return _fcmToken;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      if (!Firebase.apps.isNotEmpty) {
        print('⚠️ Firebase not initialized, skipping FCM token save to Firestore');
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final userId = await _getUserId();
      
      await firestore.collection(_fcmTokensCollection).doc(userId).set({
        'token': token,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': _getPlatform(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved to Firestore');
    } catch (e) {
      print('❌ Error saving FCM token to Firestore: $e');
    }
  }

  // Save FCM token locally
  Future<void> _saveFCMTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
    } catch (e) {
      print('❌ Error saving FCM token locally: $e');
    }
  }

  // Get user ID (using AuthService)
  Future<String> _getUserId() async {
    try {
      // Get from SharedPreferences (saved by AuthService)
      final prefs = await SharedPreferences.getInstance();
      
      // Try to get from saved user session
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userData = json.decode(userJson);
        final userId = userData['id']?.toString();
        final userEmail = userData['email']?.toString();
        
        if (userId != null && userId.isNotEmpty) {
          return userId;
        } else if (userEmail != null && userEmail.isNotEmpty) {
          return userEmail;
        }
      }
      
      // Fallback to device ID
      final deviceId = prefs.getString('device_id');
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      } else {
        // Generate a device ID
        final newDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', newDeviceId);
        return newDeviceId;
      }
    } catch (e) {
      return 'anonymous';
    }
  }

  // Get platform name
  String _getPlatform() {
    try {
      // This is a simple approach - you might want to use Platform.isAndroid, etc.
      return 'mobile';
    } catch (e) {
      return 'unknown';
    }
  }

  // Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.messageId}');
      _showLocalNotification(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped (app in background): ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from notification: ${message.messageId}');
        _handleNotificationTap(message);
      }
    });

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Extract event ID from message data
    final eventId = message.data['eventId'] ?? '';
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_notifications',
      'Event Notifications',
      channelDescription: 'Notifications for new events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Event',
      message.notification?.body ?? 'Tap to register now!',
      details,
      payload: eventId, // Store eventId in payload for navigation
    );
  }

  // Handle notification tap (FCM remote message)
  void _handleNotificationTap(RemoteMessage message) async {
    // Extract event ID from message data
    final eventId = message.data['eventId'];
    if (eventId != null) {
      // Navigate to event registration
      print('Navigate to event: $eventId');
      await _navigateToEvent(eventId);
    }
  }

  // Send notification to all users (called when event is created)
  // Note: This requires Cloud Functions or a backend service
  // For now, we'll create a function that can be called from Cloud Functions
  static Future<void> sendEventNotification({
    required String eventTitle,
    required DateTime eventDate,
    required String eventId,
  }) async {
    try {
      // This should be called from a Cloud Function
      // The Cloud Function will send notifications to all FCM tokens in Firestore
      print('Sending notification for event: $eventTitle');
      
      // Format date
      final dateStr = '${eventDate.month}/${eventDate.day}/${eventDate.year}';
      
      // This is a placeholder - actual implementation should be in Cloud Functions
      // Cloud Function will:
      // 1. Get all FCM tokens from Firestore
      // 2. Send notification to each token using FCM Admin SDK
      // 3. Include eventId in data payload for navigation
      
      print('Notification sent for event: $eventTitle on $dateStr');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  // Get current FCM token
  String? get fcmToken => _fcmToken;
}

