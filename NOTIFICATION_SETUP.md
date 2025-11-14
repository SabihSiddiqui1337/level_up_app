# Push Notification Setup Guide

This guide explains how to set up push notifications for the Level Up Sports app.

## Overview

The app uses Firebase Cloud Messaging (FCM) to send push notifications to users when new events are created. The notification system includes:

1. **Client-side setup**: FCM token registration and permission handling
2. **Cloud Functions**: Server-side notification sending when events are created
3. **Notification handling**: Navigation to event details when notifications are tapped

## Client-Side Setup (Already Implemented)

The client-side notification service is already implemented in `lib/services/notification_service.dart`. It:

- Requests notification permission on first app launch (before login)
- Registers FCM tokens in Firestore
- Handles foreground, background, and terminated app notification states
- Navigates to event details when notifications are tapped

## Cloud Functions Setup (Required for Production)

To send notifications when events are created, you need to deploy Cloud Functions:

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Functions

```bash
firebase init functions
```

Select:
- JavaScript (or TypeScript if preferred)
- Install dependencies with npm

### 4. Deploy Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 5. Test Notifications

1. Create an event from the admin panel
2. The Cloud Function will automatically trigger and send notifications to all registered FCM tokens
3. Check the Firebase Console > Functions > Logs for execution logs

## Android Configuration

The Android manifest already includes the necessary permissions:
- `POST_NOTIFICATIONS`
- `VIBRATE`
- `INTERNET`

## iOS Configuration

For iOS, you need to:

1. Enable Push Notifications capability in Xcode
2. Configure APNs (Apple Push Notification service) in Firebase Console
3. Upload APNs authentication key or certificate to Firebase Console

## Notification Flow

1. **User opens app for first time**: Permission dialog is shown
2. **User grants permission**: FCM token is generated and saved to Firestore
3. **Admin creates event**: Event is saved to Firestore
4. **Cloud Function triggers**: Listens to `event_notifications` collection
5. **Notification sent**: All FCM tokens receive the notification
6. **User taps notification**: App navigates to event detail screen

## Testing

### Test Notification Permission

1. Open the app for the first time
2. Permission dialog should appear (before login)
3. Grant permission
4. Check Firestore `fcm_tokens` collection for your token

### Test Notification Sending

1. Create an event from admin panel
2. Check Firestore `event_notifications` collection for the notification document
3. Check Cloud Functions logs for execution
4. Verify notification is received on test device

## Troubleshooting

### Notifications not received

1. Check if FCM token is saved in Firestore
2. Check Cloud Functions logs for errors
3. Verify notification permission is granted
4. Check device notification settings

### Permission not requested

1. Check if `hasRequestedPermission()` returns `false`
2. Verify user is logged in
3. Check `lib/main.dart` for permission request logic

### Navigation not working

1. Check if `navigatorKey` is properly initialized
2. Verify event exists in Firestore
3. Check notification payload contains `eventId`

## Notes

- Cloud Functions are required for production use
- For development/testing, you can manually send notifications from Firebase Console
- FCM tokens are automatically refreshed when they change
- Notifications work in foreground, background, and terminated app states

