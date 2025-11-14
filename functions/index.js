// Cloud Functions for Firebase
// This file should be placed in a 'functions' directory at the root of your project
// Run: npm install firebase-functions firebase-admin
// Deploy: firebase deploy --only functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Cloud Function to send notifications when a new event is created
exports.sendEventNotification = functions.firestore
  .document('event_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();
    
    // Check if notification has already been sent
    if (notificationData.sent === true) {
      console.log('Notification already sent, skipping...');
      return null;
    }
    
    const eventId = notificationData.eventId;
    const eventTitle = notificationData.eventTitle;
    const eventDate = notificationData.eventDate;
    
    try {
      // Get all FCM tokens from Firestore
      const tokensSnapshot = await admin.firestore()
        .collection('fcm_tokens')
        .get();
      
      if (tokensSnapshot.empty) {
        console.log('No FCM tokens found');
        return null;
      }
      
      // Extract all tokens
      const tokens = tokensSnapshot.docs.map(doc => doc.data().token).filter(token => token);
      
      if (tokens.length === 0) {
        console.log('No valid FCM tokens found');
        return null;
      }
      
      // Create notification message
      const message = {
        notification: {
          title: 'New Event: ' + eventTitle,
          body: 'Event Date: ' + eventDate + ' - Register now!',
        },
        data: {
          eventId: eventId,
          eventTitle: eventTitle,
          eventDate: eventDate,
          type: 'event_created',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'event_notifications',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        tokens: tokens, // Send to multiple tokens
      };
      
      // Send notification using FCM Admin SDK
      const response = await admin.messaging().sendEachForMulticast(message);
      
      console.log('Successfully sent notification:', response.successCount);
      console.log('Failed to send notification:', response.failureCount);
      
      // Mark notification as sent
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
      
      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      // Mark notification as failed
      await snap.ref.update({
        sent: false,
        error: error.message,
      });
      return null;
    }
  });

